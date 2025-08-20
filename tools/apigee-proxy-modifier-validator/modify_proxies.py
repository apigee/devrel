#!/usr/bin/env python3

# Copyright 2025 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import argparse
import difflib
import json
import logging
import os
import re
import sys
import tempfile
import zipfile
from pathlib import Path
import multiprocessing

import google.auth
import google.auth.transport.requests
import requests
import tomlkit
from lxml import etree

# Setup basic logging configuration
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - [%(funcName)s] %(message)s',
    handlers=[logging.StreamHandler(sys.stdout)]
)
logger = logging.getLogger() # Get the root logger

# Apigee API base URL
APIGEE_BASE_URL = "https://apigee.googleapis.com/v1"

# Status strings for reporting consistency
STATUS_YES = "Yes"
STATUS_NO = "No"
STATUS_SKIPPED = "Skipped"
STATUS_DISABLED = "Disabled"
STATUS_PENDING = "Pending"

# Detailed Validation Status Constants
VAL_SUCCESS = "Success (API Call OK)"
VAL_SUCCESS_WITH_ISSUES = "Success (API Issues Found)"
VAL_FAILED_API_ERROR = "Failed (API HTTP Error)"
VAL_FAILED_AUTH = "Failed (Auth Error)"
VAL_FAILED_NETWORK = "Failed (Network/Request Error)"
VAL_FAILED_FILE = "Failed (Bundle Not Found)"
VAL_FAILED_UNKNOWN = "Failed (Unknown Validation Error)"
VAL_SKIPPED_MODIFY_FAILED = "Skipped (Modify Failed)"
VAL_SKIPPED_NAME_INF = "Failed (Name Inference)"
VAL_SKIPPED_DISABLED = "Disabled"
VAL_SKIPPED_PENDING = "Pending" # Intermediate state, shouldn't be final
VAL_SKIPPED_EXISTS = "Skipped (Output Exists)"
VAL_FAILED_SETUP = "Failed (Setup Error)"


# --- Helper Functions ---

def parse_config(config_path: Path) -> dict | None:
    """Parses the TOML configuration file."""
    logger.info(f"Parsing configuration file: {config_path}")
    if not config_path.is_file():
        logger.error(f"Configuration file not found: {config_path}")
        return None
    try:
        with open(config_path, 'r', encoding='utf-8') as f:
            config = tomlkit.parse(f.read())
        logger.info("Configuration parsed successfully.")
        return config
    except Exception as e:
        logger.error(f"Error parsing TOML file {config_path}: {e}")
        raise

def infer_proxy_name(bundle_path: Path) -> str | None:
    """
    Infers the Apigee proxy name from the bundle filename stem.
    Removes common revision/version patterns (_revN, -revN, _vN).
    """
    stem = bundle_path.stem
    logger.debug(f"Inferring name from stem: '{stem}'")

    # Order matters for patterns like _rev1 vs _rev10
    patterns_to_remove = [r"_rev\d+$", r"-rev\d+$", r"_v\d+$"]
    inferred_name = stem
    for pattern in patterns_to_remove:
        inferred_name = re.sub(pattern, '', inferred_name, count=1)

    # Remove potential leading/trailing junk after suffix removal
    inferred_name = inferred_name.strip().strip('-_')

    if not inferred_name:
        logger.warning(f"Could not infer valid proxy name from stem: '{stem}'")
        return None

    logger.info(f"Inferred name: '{inferred_name}' for {bundle_path.name}")
    return inferred_name

def _extract_error_snippet(response_content: str, max_len: int = 150) -> str:
    """
    Attempts to extract a concise summary of error messages from response content.
    Prioritizes extracting messages from any 'violations' list found
    within the error details. Joins multiple violations.
    """
    snippet = "No details extracted" # Default if extraction fails
    if not response_content:
        return "" # Return empty if no content
    violations_found = [] # List to hold formatted violation strings

    try:
        # Attempt to parse as JSON first
        data = json.loads(response_content)
        if isinstance(data, dict):
            # --- Check specifically for 'violations' within 'error.details' first ---
            if 'error' in data and isinstance(data['error'], dict) and 'details' in data['error']:
                details = data['error']['details']
                if isinstance(details, list):
                    # Iterate through *all* items in the 'details' list
                    for detail_item in details:
                        # Check if this detail item *contains* a 'violations' key with a list value
                        if isinstance(detail_item, dict) and \
                           'violations' in detail_item and \
                           isinstance(detail_item['violations'], list):
                            for violation in detail_item['violations']:
                                violation_text = "Unknown violation detail" # Default
                                if isinstance(violation, dict):
                                    # Attempt to get common fields, fallback gracefully
                                    filename = violation.get('filename', None)
                                    desc = violation.get('description', None)
                                    msg = violation.get('message', None)
                                    violation_text = desc or msg or violation_text # Prioritize description/message
                                    if filename:
                                        violations_found.append(f"{filename}: {violation_text}")
                                    else:
                                        violations_found.append(violation_text)

                                elif isinstance(violation, str): # Handle simple string violations
                                     violations_found.append(violation)

            # --- If specific violations were extracted, format and return them ---
            if violations_found:
                snippet = "; ".join(violations_found)
                logger.debug(f"Extracted {len(violations_found)} violations: {snippet[:500]}...") # Log snippet of joined violations
                # Truncate the final combined string if needed for the report cell
                if len(snippet) > max_len:
                    snippet = snippet[:max_len-3] + "..."
                return snippet # Return the combined violation details

            # --- Fallback to other common error keys if no violations were processed ---
            logger.debug("No 'violations' found or processed in error details, checking common keys.")
            if 'error' in data and isinstance(data['error'], dict):
                # Prioritize error.message if available
                if 'message' in data['error']:
                    snippet = data['error']['message']
                # Check for other potential details if message is generic
                elif 'detail' in data['error']: # Sometimes detail is nested here
                    snippet = data['error']['detail']
                elif 'status' in data['error']: # Fallback to status
                    snippet = f"Status: {data['error']['status']}"
            elif 'message' in data: # Top-level message
                snippet = data['message']
            elif 'fault' in data and isinstance(data['fault'], dict) and 'faultstring' in data['fault']: # SOAP Fault style
                snippet = data['fault']['faultstring']
            elif 'detail' in data: # Top-level detail
                snippet = data['detail']
            elif 'error' in data and isinstance(data['error'], str): # Simple top-level error string
                snippet = data['error']
            else:
                # Fallback if known keys aren't found in JSON
                snippet = "JSON error content (see logs)"

        elif isinstance(data, list) and data: # Handle case where root is a list
             logger.debug("Response is a list, extracting from first item.")
             first_item = data[0]
             if isinstance(first_item, str): snippet = first_item
             elif isinstance(first_item, dict) and 'message' in first_item: snippet = first_item['message']
             else: snippet = "Error list found (see logs)"

    except json.JSONDecodeError:
        # If it's not JSON, try to get the first non-empty line or a snippet
        logger.debug("Response is not JSON, extracting first line.")
        lines = [line.strip() for line in response_content.strip().splitlines() if line.strip()]
        if lines:
            snippet = lines[0] # Take the first meaningful line
        else:
            snippet = response_content.strip() # Fallback to raw stripped content

    # --- Final Cleanup and Truncation for Fallback Snippets ---
    if isinstance(snippet, str):
        snippet = snippet.replace('\n', ' ').replace('\r', '').strip()
        # Apply truncation only if violations weren't already handled (as they have their own truncation)
        if not violations_found and len(snippet) > max_len:
            snippet = snippet[:max_len-3] + "..."
    else:
        # Handle unexpected types from fallback extraction
        snippet = "Error details unavailable"

    logger.debug(f"Extracted fallback snippet: {snippet}")
    if snippet:
        return snippet
    else:
        return "Error details unavailable"

# --- XML Modification Core Logic (using lxml) ---

def modify_xml_file_lxml(xml_path: Path, rules: dict) -> bool:
    """
    Parses/modifies an XML file using lxml based on TOML rules, preserving format.

    Supports modes based on TOML keys present in a rule:
    - conditional_prefix: Prepends 'prefix' if 'from' matches existing value
                          (respects 'exact_match' flag).
    - prefix: Prepends 'prefix' regardless of existing value.
    - suffix: Appends 'suffix' regardless of existing value.
    - set_replace: Uses 'to' and optional 'from'. Sets value or replaces 'from'
                   (respects 'exact_match' flag for replacement).
    - remove_if_empty: Removes element if it's empty (no text, no children).
    - trim_value: Trims leading/trailing whitespace from the target value.

    Requires 'xpath' key in rule.
    Optional 'exact_match = true' for 'from' value.

    Returns True if content was modified AND saved, False otherwise.
    """
    logger.info(f"Processing {xml_path.name} using lxml.")
    content_was_modified_and_saved = False
    try:
        # Configure parser to preserve structure
        parser = etree.XMLParser(
            remove_blank_text=False,
            strip_cdata=False,
            remove_comments=False
        )
        tree = etree.parse(str(xml_path), parser)
        root = tree.getroot()

        root_tag_name = root.tag
        if not root_tag_name:
            logger.error(f"Could not determine root element for {xml_path.name}")
            return False

        if root_tag_name not in rules:
            logger.debug(
                f"No rules defined for root element '{root_tag_name}' in {xml_path.name}"
            )
            return False

        policy_rules = rules[root_tag_name]
        any_change_made_to_tree = False
        logger.debug(
            f"Applying rules for element type '{root_tag_name}' to {xml_path.name}"
        )

        # --- Iterate through rules ---
        for rule_name, rule_details in policy_rules.items():
            logger.debug(f"  Applying rule: '{rule_name}'")

            # --- Extract rule parameters ---
            xpath_expr = rule_details.get('xpath')
            target_type = rule_details.get('target_type')
            attribute_name = rule_details.get('attribute_name')
            from_str = rule_details.get('from')
            to_str = rule_details.get('to')
            prefix_str = rule_details.get('prefix')
            suffix_str = rule_details.get('suffix')
            action = rule_details.get('action') # e.g., "remove_if_empty", "trim_value"

            exact_match = rule_details.get('exact_match', False)
            if not isinstance(exact_match, bool):
                logger.warning(
                    f"  Rule '{rule_name}': Invalid 'exact_match' value ('{rule_details.get('exact_match')}'), "
                    "defaulting to False."
                )
                exact_match = False

            # Basic parameter checks
            if not xpath_expr:
                logger.warning(f"  Skipping rule '{rule_name}': Missing required 'xpath'.")
                continue

            # Determine modification mode and check exclusivity
            mode = None
            has_prefix = prefix_str is not None
            has_suffix = suffix_str is not None
            has_to = to_str is not None
            has_from = from_str is not None

            # Prioritize 'action' if present
            if action == "remove_if_empty":
                mode = "remove_if_empty"
                if has_prefix or has_suffix or has_to or has_from:
                    logger.warning(f"Skipping rule '{rule_name}': 'action: remove_if_empty' incompatible with value modification keys.")
                    continue
            elif action == "trim_value":
                mode = "trim_value"
                if has_prefix or has_suffix or has_to or has_from: # from might be ok for conditional trim, but not yet supported
                    logger.warning(f"Skipping rule '{rule_name}': 'action: trim_value' incompatible with value modification keys.")
                    continue
            # Determine mode based on other keys if no 'action' or action is not handled above
            elif has_prefix and has_from and not has_suffix and not has_to:
                mode = "conditional_prefix"
            elif has_prefix and not has_from and not has_suffix and not has_to:
                mode = "prefix"
            elif has_suffix and not has_from and not has_prefix and not has_to:
                mode = "suffix"
            elif has_to and not has_prefix and not has_suffix: # 'from' is optional for set_replace
                mode = "set_replace"

            if not mode:
                logger.warning(
                    f"  Skipping rule '{rule_name}': No valid operation defined or conflicting keys. "
                    "Ensure one of 'action', 'prefix', 'suffix', or 'to' is primary."
                )
                continue

            # Validate 'exact_match' usage
            if exact_match and not has_from and mode in ["conditional_prefix", "set_replace"]:
                logger.warning(f"Rule '{rule_name}': 'exact_match=true' requires 'from' for mode '{mode}'. Ignoring exact_match.")
                exact_match = False

            # Further validation for modes other than remove_if_empty/trim_value
            if mode not in ["remove_if_empty", "trim_value"]:
                if not target_type:
                    logger.warning(f"Skipping rule '{rule_name}': Missing 'target_type' for mode '{mode}'.")
                    continue
                if target_type == 'attribute' and not attribute_name:
                    logger.warning(f"Skipping rule '{rule_name}': 'attribute_name' required for target_type 'attribute' in mode '{mode}'.")
                    continue
            # For trim_value, target_type is also required
            elif mode == "trim_value":
                if not target_type:
                    logger.warning(f"Skipping rule '{rule_name}': Missing 'target_type' for mode 'trim_value'.")
                    continue
                if target_type == 'attribute' and not attribute_name:
                     logger.warning(f"Skipping rule '{rule_name}': 'attribute_name' required for target_type 'attribute' in mode 'trim_value'.")
                     continue

            # --- Find Elements and Apply Modification ---
            try:
                elements_found = root.xpath(xpath_expr)
                if not elements_found:
                    logger.debug(f"  Rule '{rule_name}': XPath '{xpath_expr}' found no elements.")
                    continue

                made_change_this_rule = False
                for element in elements_found:
                    if mode == "remove_if_empty":
                        has_text_content = element.text and element.text.strip()
                        has_child_elements = len(element) > 0
                        if not has_text_content and not has_child_elements:
                            parent = element.getparent()
                            if parent is not None:
                                parent.remove(element)
                                made_change_this_rule = True
                                logger.info(f"  Removed empty element via rule '{rule_name}'.")
                            else:
                                logger.warning(f"  Rule '{rule_name}': Element has no parent (is it root?). Cannot remove.")
                        else:
                             logger.debug(f"  Rule '{rule_name}': Element not empty, not removed.")
                        continue # Process next element or rule

                    # --- Logic for modes that modify values ---
                    value_changed = False
                    current_value = ""

                    if target_type == 'text':
                        current_value = element.text if element.text is not None else ""
                    elif target_type == 'attribute':
                        current_value = element.get(attribute_name, "")

                    new_value = current_value # Default: no change
                    apply_modification = False

                    if mode == "trim_value":
                        new_value = current_value.strip()
                        apply_modification = True # Always attempt to apply trim
                    elif mode == "conditional_prefix":
                        condition_met = (exact_match and current_value == from_str) or \
                                        (not exact_match and has_from and from_str in current_value)
                        if condition_met:
                            new_value = prefix_str + current_value
                            apply_modification = True
                    elif mode == "prefix":
                        new_value = prefix_str + current_value
                        apply_modification = True
                    elif mode == "suffix":
                        new_value = current_value + suffix_str
                        apply_modification = True
                    elif mode == "set_replace":
                        if from_str is None:
                            new_value = to_str
                            apply_modification = True
                        else:
                            condition_met = (exact_match and current_value == from_str) or \
                                            (not exact_match and from_str in current_value)
                            if condition_met:
                                new_value = to_str if exact_match else current_value.replace(from_str, to_str)
                                apply_modification = True

                    # Update the element ONLY if modification was flagged AND new value differs
                    if apply_modification and new_value != current_value:
                        if target_type == 'text':
                            element.text = new_value
                        elif target_type == 'attribute':
                            element.set(attribute_name, new_value)
                        value_changed = True

                    if value_changed:
                        made_change_this_rule = True
                        match_type_log = "(Exact Match)" if exact_match and has_from and mode != "trim_value" else ""
                        logger.info(
                           f"  Applied change via rule '{rule_name}' (Mode: {mode}{match_type_log}) to element matching XPath."
                        )

                # If this rule made any change to any element, mark the tree dirty
                if made_change_this_rule:
                    any_change_made_to_tree = True

            except etree.XPathError as e:
                logger.warning(f"  Skipping rule '{rule_name}': Invalid XPath '{xpath_expr}': {e}")
            except Exception as e:
                logger.error(f"  Error applying rule '{rule_name}' to {xml_path.name}: {e}", exc_info=False)

        # --- Save file only if the lxml tree was modified ---
        if any_change_made_to_tree:
            logger.info(f"Saving changes to {xml_path.name} (using lxml)")
            try:
                tree.write(
                    str(xml_path),
                    encoding='utf-8',
                    xml_declaration=True,
                    pretty_print=True
                )
                content_was_modified_and_saved = True
                logger.info(f"Successfully saved modified XML: {xml_path.name}")
            except Exception as e:
                 logger.error(f"Error writing modified XML for {xml_path.name} using lxml: {e}")
                 return False
        else:
            logger.debug(f"No modifications applied by rules to {xml_path.name}, skipping save.")

    # Handle file/XML level errors
    except FileNotFoundError:
        logger.error(f"XML file not found: {xml_path}")
    except etree.XMLSyntaxError as xml_err:
        logger.error(f"Invalid XML structure in {xml_path.name}: {xml_err}")
    except Exception as e:
        logger.error(f"Failed to process XML file {xml_path.name} using lxml: {e}", exc_info=False)

    return content_was_modified_and_saved

# --- Bundle Processing Logic ---

def process_bundle(
    bundle_path: Path,
    config_path: Path,
    output_path: Path,
    rules: dict
) -> tuple[bool, bool, dict[str, str]]:
    """
    Processes a single API proxy bundle: extracts, modifies XML files (using lxml), re-zips.

    Returns tuple (processing_completed, any_xml_changed, diff_details):
      - processing_completed: True if process ran end-to-end without critical errors.
      - any_xml_changed: True if any XML file content was actually modified.
      - diff_details: Dictionary mapping relative_path: diff_string for changed files.
    """
    logger.info(f"--- Processing bundle: {bundle_path.name} ---")
    processing_completed = False
    any_xml_changed_in_bundle = False
    diff_details = {} # Dictionary to store diffs {relative_path: diff_string}
    original_contents = {} # Store original content {relative_path: content}

    # Input validation
    if not bundle_path.is_file() or bundle_path.suffix.lower() != '.zip':
        logger.error(f"Input path is not a valid ZIP file: {bundle_path}")
        return processing_completed, any_xml_changed_in_bundle, diff_details
    if not rules:
        logger.error("Cannot process bundle, rules dictionary is empty.")
        return processing_completed, any_xml_changed_in_bundle, diff_details

    try:
        # Use temporary directory for extraction and modification
        with tempfile.TemporaryDirectory() as temp_dir:
            temp_dir_path = Path(temp_dir)
            logger.info(f"Extracting bundle to temporary directory: {temp_dir_path}")
            try:
                with zipfile.ZipFile(bundle_path, 'r') as zip_ref:
                    zip_ref.extractall(temp_dir_path)
            except Exception as e:
                logger.error(f"Error extracting ZIP file {bundle_path}: {e}")
                return processing_completed, any_xml_changed_in_bundle, diff_details

            # --- Scan specified subdirectories for XML files ---
            base_apiproxy_dir = temp_dir_path / 'apiproxy'
            dirs_to_scan = {
                "policies": base_apiproxy_dir / 'policies',
                "proxies": base_apiproxy_dir / 'proxies',
                "targets": base_apiproxy_dir / 'targets'
            }

            modification_scan_successful = True # Track if any XML processing fails

            for dir_key, dir_path in dirs_to_scan.items():
                if dir_path.is_dir():
                    logger.info(f"Scanning directory: {dir_path}")
                    for item in dir_path.iterdir():
                        if item.is_file() and item.suffix.lower() == '.xml':
                            relative_path = item.relative_to(temp_dir_path).as_posix() # Use consistent path sep
                            logger.debug(f"Processing {dir_key} file: {item.name} ({relative_path})")

                            # --- Store Original Content ---
                            try:
                                # Read bytes first for consistent diffing, then decode
                                original_bytes = item.read_bytes()
                                original_content = original_bytes.decode('utf-8')
                                original_contents[relative_path] = original_content
                            except Exception as read_err:
                                logger.error(f"Error reading original file {relative_path}: {read_err}")
                                modification_scan_successful = False
                                continue # Skip this file

                            # --- Attempt Modification ---
                            file_was_modified = False
                            try:
                                file_was_modified = modify_xml_file_lxml(item, rules)

                                if file_was_modified:
                                    any_xml_changed_in_bundle = True
                                    logger.info(f"File content was modified: {relative_path}")

                                    # --- Generate Diff if Modified ---
                                    try:
                                        # Read modified bytes and decode
                                        modified_bytes = item.read_bytes()
                                        modified_content = modified_bytes.decode('utf-8')

                                        # Generate diff using decoded strings
                                        diff = difflib.unified_diff(
                                            original_content.splitlines(keepends=True),
                                            modified_content.splitlines(keepends=True),
                                            fromfile=relative_path + ' (original)',
                                            tofile=relative_path + ' (modified)',
                                            lineterm='\n',
                                            n=3 # Number of context lines
                                        )
                                        diff_string = "".join([ f"{each_ds}\n" if not each_ds.endswith("\n") else each_ds for each_ds in diff ])
                                        if diff_string: # Only store if diff is not empty
                                             diff_details[relative_path] = diff_string
                                             logger.debug(f"Generated diff for {relative_path}")
                                        else:
                                             # This case might happen if only whitespace/encoding changed
                                             logger.info(f"File {relative_path} saved but no textual diff detected by difflib.")
                                             diff_details[relative_path] = "(Formatting changes only detected)\n"


                                    except Exception as diff_err:
                                        logger.error(f"Error generating diff for {relative_path}: {diff_err}")
                                        # Store placeholder indicating diff error
                                        diff_details[relative_path] = f"--- Error generating diff: {diff_err} ---\n"

                            except Exception as e:
                                logger.error(
                                    f"Critical error during modify call for {item.name} in {dir_key}: {e}",
                                    exc_info=True
                                )
                                modification_scan_successful = False
                else:
                    logger.debug(f"Directory not found or is not a directory: {dir_path}")

            if not modification_scan_successful:
                logger.error(
                    f"Bundle processing stopped due to errors during XML modification for: {bundle_path.name}"
                )
                return processing_completed, any_xml_changed_in_bundle, diff_details

            logger.info(
                f"Finished XML scan for {bundle_path.name}. Any content changes made: {any_xml_changed_in_bundle}"
            )

            # --- Re-zipping (only if scan was successful) ---
            logger.info(f"Creating output bundle: {output_path}")
            try:
                output_path.parent.mkdir(parents=True, exist_ok=True)
                with zipfile.ZipFile(output_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
                    for root_dir_str, _, files in os.walk(temp_dir_path):
                        root_dir = Path(root_dir_str)
                        for file in files:
                            file_path = root_dir / file
                            arcname = file_path.relative_to(temp_dir_path)
                            zipf.write(file_path, arcname)
                logger.info(f"Successfully created bundle: {output_path}")
                processing_completed = True
            except Exception as e:
                logger.error(f"Error creating output ZIP file {output_path}: {e}")

    except Exception as outer_e:
        logger.error(
            f"Outer error during bundle processing for {bundle_path.name}: {outer_e}",
            exc_info=True
        )

    return processing_completed, any_xml_changed_in_bundle, diff_details


# --- Validation Logic ---

def validate_bundle(bundle_path: Path, org_id: str, proxy_name: str) -> tuple[str, str]:
    """
    Validates a single API proxy bundle via Apigee API.
    Logs detailed response info, especially on failure or issues.
    Returns a tuple: (detailed_status_string, error_snippet_string).
    """
    logger.info(f"Attempting validation for {bundle_path.name} using name: '{proxy_name}'")
    error_snippet = ""
    if not org_id or not proxy_name:
        logger.error("Organization ID and Proxy Name are required for validation.")
        return VAL_FAILED_UNKNOWN, "Setup Error"
    response_content = ""
    try:
        logger.debug("Fetching Application Default Credentials (ADC)...")
        credentials, project_id = google.auth.default(scopes=['https://www.googleapis.com/auth/cloud-platform'])
        logger.debug(f"Using ADC for project: {project_id or 'Default'}")
        auth_req = google.auth.transport.requests.Request()
        credentials.refresh(auth_req)
        authed_session = google.auth.transport.requests.AuthorizedSession(credentials)
        validate_url = f"{APIGEE_BASE_URL}/organizations/{org_id}/apis"
        params = {'action': 'validate', 'validate': 'true', 'name': proxy_name}
        headers = {'Content-Type': 'application/octet-stream'}
        logger.info(f"Sending validation request for '{proxy_name}'")
        with open(bundle_path, 'rb') as f:
            response = authed_session.post(validate_url, params=params, headers=headers, data=f)
        response_content = response.text
        logger.info(f"Validation API response status for '{proxy_name}': {response.status_code}")
        if logger.level == logging.DEBUG:
            logger.debug(f"START API Response Body [{proxy_name}]:\n{response_content}\nEND API Response Body [{proxy_name}]")
        else:
            logger.info(f"API Response Body Snippet [{proxy_name}]:\n{response_content[:1000] + ('...' if len(response_content) > 1000 else '')}")
        if response.ok:
            logger.info(f"Validation request OK (HTTP {response.status_code}) for '{proxy_name}'.")
            if '"error"' in response_content.lower() or '"validationerrors"' in response_content.lower():
                logger.warning(f"[{proxy_name}] Validation OK, but API indicates issues. See response.")
                error_snippet = _extract_error_snippet(response_content)
                return VAL_SUCCESS_WITH_ISSUES, error_snippet
            else:
                return VAL_SUCCESS, ""
        else:
            logger.error(f"[{proxy_name}] Validation API request failed (HTTP {response.status_code}).")
            error_snippet = _extract_error_snippet(response_content)
            return VAL_FAILED_API_ERROR, error_snippet
    except google.auth.exceptions.DefaultCredentialsError as e:
        logger.error(f"[{proxy_name}] Auth Error: {e}")
        print("Auth Error")
        return VAL_FAILED_AUTH, "ADC Auth Failed"
    except requests.exceptions.RequestException as e:
        logger.error(f"[{proxy_name}] Network/Request Error: {e}")
        return VAL_FAILED_NETWORK, "Network/Request Error"
    except FileNotFoundError:
        logger.error(f"[{proxy_name}] Bundle not found: {bundle_path}")
        return VAL_FAILED_FILE, "Bundle File Missing"
    except Exception as e:
        logger.error(f"[{proxy_name}] Unknown Error during validation: {e}", exc_info=True)
        error_snippet = _extract_error_snippet(response_content) if response_content else "Unknown Error"
        return VAL_FAILED_UNKNOWN, error_snippet[:80]

# --- Worker function for parallel processing ---
def process_single_bundle_worker(
    bundle_path_str: str,
    output_dir_str: str,
    rules: dict,
    config_path_str: str, # For logging context in process_bundle
    org_id: str | None,
    validate_flag: bool,
    overwrite_flag: bool,
    # verbose_flag: bool, # verbose_flag not directly used in worker to set log level, inherited
    bundle_idx: int,
    total_bundles: int
) -> list:
    """
    Worker function to process a single bundle.
    Designed to be called by multiprocessing.Pool.
    """
    # Convert string paths back to Path objects
    bundle_path = Path(bundle_path_str)
    output_dir = Path(output_dir_str)
    config_path_for_logging = Path(config_path_str)


    current_bundle_name = bundle_path.name
    output_bundle_path = output_dir / current_bundle_name
    processing_completed, any_xml_changed = False, False
    validation_status_detail = VAL_SKIPPED_DISABLED if not validate_flag else VAL_SKIPPED_PENDING
    validation_error_snippet = ""
    diff_details = {}

    # This print will be from a worker process; order might be interleaved with other workers.
    print(f"\n[{bundle_idx + 1}/{total_bundles}] Processing: {current_bundle_name}")

    if output_bundle_path.exists():
        if not overwrite_flag:
            logger.warning(f"Output exists, skipping: {output_bundle_path}")
            print(f"Skipping - Exists: {current_bundle_name}")
            modified_status_str = STATUS_NO
            validation_status_detail = VAL_SKIPPED_EXISTS
            validation_error_snippet = "Skipped (Output Exists)"
            return [current_bundle_name, modified_status_str, validation_status_detail, validation_error_snippet, {}]
        else:
            logger.warning(f"Overwriting: {output_bundle_path}")
            print(f"Overwriting: {current_bundle_name}")

    try:
        # Pass the original config_path (as Path object) for potential logging inside process_bundle
        processing_completed, any_xml_changed, diff_details = process_bundle(
            bundle_path, config_path_for_logging, output_bundle_path, rules
        )
        log_msg = "Mod process completed." + (f" Content changed: {STATUS_YES}" if any_xml_changed else f" Content unchanged: {STATUS_NO}")
        if processing_completed:
            logger.info(log_msg)
            print(f"✅ Mod Process Finished: {current_bundle_name}")
        else:
            logger.error(f"Mod Process Failed: {current_bundle_name}")
            print(f"❌ Mod Process Failed: {current_bundle_name}")
    except Exception as e:
        processing_completed = False
        any_xml_changed = False
        diff_details = {}
        logger.error(f"Unexpected error processing {current_bundle_name}: {e}", exc_info=True)
        print(f"❌ Error during modification: {current_bundle_name}")

    modified_status_str = STATUS_YES if any_xml_changed else STATUS_NO

    if validate_flag:
        if processing_completed:
            if not org_id: # Should be caught by argparse if --validate is set
                logger.error(f"Org ID missing for validation of {current_bundle_name}")
                validation_status_detail = VAL_FAILED_SETUP # A new status or use existing
                validation_error_snippet = "Org ID missing for validation"
            else:
                print(f"Attempting validation for {current_bundle_name}...")
                inferred_name = infer_proxy_name(bundle_path)
                if inferred_name:
                    try:
                        validation_status_detail, validation_error_snippet = validate_bundle(output_bundle_path, org_id, inferred_name)
                        if VAL_SUCCESS in validation_status_detail:
                            print(f"✅ Validation finished for '{inferred_name}'. Status: {validation_status_detail}")
                        else:
                            print(f"❌ Validation finished for '{inferred_name}'. Status: {validation_status_detail}")
                    except Exception as val_e:
                        validation_status_detail = VAL_FAILED_UNKNOWN
                        validation_error_snippet = "Unknown Validation Exception"
                        logger.error(f"Validation exception: {val_e}", exc_info=True)
                        print(f"❌ Error during validation call.")
                else:
                    validation_status_detail = VAL_SKIPPED_NAME_INF
                    validation_error_snippet = "Cannot infer name"
                    print(f"❌ Skipping validation - cannot infer name.")
        else:
            validation_status_detail = VAL_SKIPPED_MODIFY_FAILED
            validation_error_snippet = "Modify process failed"
            print("Skipping validation (modify failed).")

    return [current_bundle_name, modified_status_str, validation_status_detail, validation_error_snippet, diff_details]


# --- Main Execution Logic ---

def main():
    """Parses arguments, orchestrates bundle processing and validation, generates MD report."""
    parser = argparse.ArgumentParser(
        description="Modify/validate Apigee bundles and generate Markdown report (lxml).",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter
    )
    # --- Argument parsing ---
    parser.add_argument("--input-dir", type=Path, required=True, help="Input directory.")
    parser.add_argument("--output-dir", type=Path, required=True, help="Output directory for bundles.")
    parser.add_argument("--config-path", type=Path, required=True, help="TOML config path (using xpath).")
    parser.add_argument("--validate", action="store_true", help="Validate bundles.")
    parser.add_argument("--org", type=str, required='--validate' in sys.argv, help="Apigee Org ID (for --validate).")
    parser.add_argument("--overwrite", action="store_true", help="Overwrite output bundle files.")
    parser.add_argument(
        "--report-file", type=Path, required=True,
        help="Path to save the output Markdown report file (e.g., report.md)."
    )
    parser.add_argument("-v", "--verbose", action="store_true", help="Enable debug logging (affects console output).")
    parser.add_argument(
        "--workers", type=int, default=os.cpu_count(),
        help="Number of worker processes for parallel bundle processing. Defaults to number of CPU cores."
    )
    args = parser.parse_args()

    logger.setLevel(logging.DEBUG if args.verbose else logging.INFO)

    # --- Path validation and directory setup ---
    input_dir, output_dir, config_path = args.input_dir.resolve(), args.output_dir.resolve(), args.config_path
    if not input_dir.is_dir():
        logger.critical(f"Invalid input dir: {input_dir}")
        sys.exit(1)
    if output_dir.exists() and not output_dir.is_dir():
        logger.critical(f"Output not dir: {output_dir}")
        sys.exit(1)
    if input_dir == output_dir:
        logger.critical("Input/output dirs cannot be same.")
        sys.exit(1)
    try:
        output_dir.mkdir(parents=True, exist_ok=True)
        logger.info(f"Output dir: {output_dir}")
    except OSError as e:
        logger.critical(f"Cannot create output dir {output_dir}: {e}")
        sys.exit(1)

    # --- Config parsing ---
    try:
        rules = parse_config(config_path)
        assert rules is not None
    except Exception as cfg_err:
        logger.critical(f"Failed to load config: {cfg_err}")
        sys.exit(1)

    # --- Start Processing ---
    print(f"--- Starting Bundle Processing from: {input_dir} ---")
    if args.validate:
        print(f"--- Validation ENABLED for org '{args.org}' (inferred names) ---")
    print("--- INFO: Using lxml for XML modification to preserve formatting. ---")

    bundles_found = sorted(list(input_dir.glob('*.zip')))
    total_bundles = len(bundles_found)
    results_data = []

    if not bundles_found:
        logger.warning(f"No .zip files found in input directory: {input_dir}")
        print("No .zip bundles found to process.")
        try:
            with open(args.report_file, 'w', encoding='utf-8') as f:
                f.write("# Bundle Processing Report\n\n")
                f.write("No .zip bundles found in the input directory.\n")
            print(f"Empty report saved to: {args.report_file}")
        except Exception as e:
            logger.error(f"Failed to write empty report file: {e}")
        sys.exit(0)

    logger.info(f"Found {total_bundles} bundle(s). Using up to {args.workers} worker processes.")
    print(f"--- Found {total_bundles} bundle(s). Using up to {args.workers} worker processes. ---")

    tasks = []
    for i, bundle_path_iter in enumerate(bundles_found):
        tasks.append((
            str(bundle_path_iter),
            str(output_dir), # output_dir is already resolved Path
            rules,
            str(config_path), # config_path is Path from args
            args.org,
            args.validate,
            args.overwrite,
            # args.verbose, # Not passing verbose, logger level is inherited
            i,
            total_bundles
        ))

    if tasks:
        # Ensure pool is properly closed, especially if errors occur
        try:
            with multiprocessing.Pool(processes=args.workers) as pool:
                results_data = pool.starmap(process_single_bundle_worker, tasks)
        except Exception as e:
            logger.critical(f"A critical error occurred during parallel processing: {e}", exc_info=True)
            # Decide if to exit or try to generate a partial report
            # For now, let it proceed to report generation with whatever results_data contains (likely empty or partial)
            if not results_data: # If pool init failed or starmap didn't even start
                 results_data = [] # Ensure it's a list for report generation
    else: # Should be caught by "if not bundles_found"
        results_data = []


    # --- Generate Markdown Report Content ---
    report_lines = []
    report_lines.append("# Bundle Processing Report")
    report_lines.append(f"Processed bundles from: `{args.input_dir}`")
    report_lines.append(f"Output saved to: `{args.output_dir}`")
    report_lines.append(f"Config file used: `{args.config_path}`")
    report_lines.append("\n---\n") # Separator

    # --- Summary Counts ---
    report_lines.append("## Overall Summary")
    modified_yes_count = sum(1 for r in results_data if r and len(r) > 1 and r[1] == STATUS_YES)
    # total_processed_or_skipped = len(results_data) # This now reflects tasks submitted/completed
    # Recalculate based on actual results, as some might have failed to return proper structure if worker crashed early
    valid_results_count = sum(1 for r in results_data if r and len(r) > 1)
    modified_no_count = valid_results_count - modified_yes_count

    report_lines.append(f"*   **Total Bundles Found:** {total_bundles}")
    report_lines.append(f"*   **Bundles Processed (attempted):** {valid_results_count}") # Number of results returned
    report_lines.append(f"*   **Bundles with XML changes:** {modified_yes_count}")
    report_lines.append(f"*   **Bundles unchanged/skipped/failed modify (among processed):** {modified_no_count}")


    if args.validate:
        val_success_count = sum(1 for r in results_data if r and len(r) > 2 and r[2] in [VAL_SUCCESS, VAL_SUCCESS_WITH_ISSUES])
        val_failed_count = sum(1 for r in results_data if r and len(r) > 2 and r[2].startswith("Failed"))
        val_skipped_disabled_count = sum(1 for r in results_data if r and len(r) > 2 and (r[2].startswith("Skipped") or r[2] == VAL_SKIPPED_DISABLED))
        report_lines.append(f"*   **Validation Success (API Call OK):** {val_success_count}")
        report_lines.append(f"*   **Validation Failed:** {val_failed_count}")
        report_lines.append(f"*   **Validation Skipped/Disabled:** {val_skipped_disabled_count}")
    report_lines.append("\n---\n")

    # --- Summary Table Generation ---
    report_lines.append("## Summary Table")
    if results_data:
        headers = ["Proxy Bundle", "Modified", "Validation Result", "Validation Detail Snippet"]
        report_lines.append("| " + " | ".join(headers) + " |")
        report_lines.append("|" + "---|" * len(headers))

        for row in results_data:
            if not row or len(row) < 4: # Gracefully handle incomplete results from failed workers
                logger.warning(f"Skipping malformed row in report generation: {row}")
                report_lines.append(f"| {'Error processing bundle'} | - | - | {'Worker failed to return full data'} |")
                continue
            bundle_name, mod_status, val_status, val_snippet_raw = row[:4]
            val_snippet_md = "`" + val_snippet_raw.replace('|', '\\|') + "`" if val_snippet_raw else ""
            report_lines.append(f"| {bundle_name} | {mod_status} | {val_status} | {val_snippet_md} |")
    else:
        report_lines.append("\nNo bundle processing results to display in table.")
    report_lines.append("\n---\n") # Separator after table

    # --- Detailed Bundle Results ---
    report_lines.append("## Bundle Details")

    if not results_data:
        report_lines.append("\nNo bundles were processed or results recorded.")
    else:
        for result_row in results_data:
            if not result_row or len(result_row) < 5: # Gracefully handle incomplete results
                report_lines.append(f"\n### Bundle: `{'Unknown (Worker Error)'}`")
                report_lines.append(f"*   **Error:** Worker failed to return complete data for this bundle.")
                continue

            bundle_name, modified_status, validation_status, validation_snippet, diff_dict = result_row

            report_lines.append(f"\n### Bundle: `{bundle_name}`")
            report_lines.append(f"*   **Modified:** {modified_status}")
            report_lines.append(f"*   **Validation Result:** {validation_status}")
            if validation_snippet:
                report_lines.append(f"*   **Validation Detail Snippet:** `{validation_snippet}`")

            if diff_dict:
                report_lines.append("\n*   **Modifications Made:**")
                for file_path, diff_content in diff_dict.items():
                    report_lines.append(f"    *   **File:** `{file_path}`")
                    report_lines.append(f"        ```diff")
                    indented_diff = "\n".join("        " + line for line in diff_content.splitlines())
                    report_lines.append(indented_diff)
                    report_lines.append(f"        ```")
            elif modified_status == STATUS_YES:
                 report_lines.append("\n*   **Modifications Made:** (No textual diff generated, likely formatting changes only)")


    report_lines.append("\n---\n")
    report_lines.append("**NOTE:** For full validation details (failures or API issues), check the script's console log output (use `-v` for maximum detail). The snippet above is only a hint.")

    # --- Write Report to File ---
    try:
        report_content = "\n".join(report_lines)
        with open(args.report_file, 'w', encoding='utf-8') as f:
            f.write(report_content)
        print(f"\nMarkdown report saved successfully to: {args.report_file}")
    except Exception as e:
        logger.error(f"Failed to write Markdown report to {args.report_file}: {e}")
        print(f"\n❌ Failed to save report file.")


if __name__ == "__main__":
    main()
