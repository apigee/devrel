# Apigee Proxy Bundle Modifier & Validator

This script assists in migrating Apigee Edge proxy bundles to Apigee X/Hybrid by allowing batch modification of policy XML files, ProxyEndpoint definitions, and TargetEndpoint definitions based on rules defined in a TOML configuration file. It uses the **`lxml` library** for modifications to better preserve XML formatting and can optionally validate the modified bundles against the Apigee API using Google Application Default Credentials (ADC). The final output is a detailed **Markdown report**.

## Purpose

During migration from Apigee Edge to Apigee X/Hybrid, certain policy configurations, endpoint settings, or target URLs might need adjustments for compatibility. This script automates the process of:

1.  Extracting an API proxy bundle (`.zip`).
2.  Parsing XML files within `apiproxy/policies/`, `apiproxy/proxies/`, and `apiproxy/targets/`.
3.  Modifying XML elements or attributes based on rules defined in a TOML file (using `lxml` and **XPath**). Supported operations include Set/Replace, Prefix, Suffix, and Conditional Prefix.
4.  Preserving original XML formatting (whitespace, comments, etc.) as much as possible during modification thanks to `lxml`.
5.  Generating detailed `diff` output only for files with actual content changes.
6.  Re-zipping the modified bundle structure.
7.  Optionally validating the modified bundle using the Apigee API (inferring the proxy name from the filename).
8.  Processing multiple bundles from an input directory to an output directory.
9.  Generating a comprehensive **Markdown report file** (`.md`) containing:
    *   Overall processing summary counts.
    *   A summary table of all processed bundles.
    *   Detailed status per bundle, including validation results and error snippets.
    *   Line-by-line diffs (using `difflib`) for all files that were modified.

## Features

*   Modifies XML files (Policies, ProxyEndpoints, TargetEndpoints) within Apigee proxy bundles.
*   Uses the **`lxml` library** for robust XML parsing and modification, aiming to preserve formatting.
*   Uses a TOML file for defining modification rules using **XPath expressions**.
*   Supports multiple modification operations: Set/Replace (with wildcard 'from'), Prefix, Suffix, Conditional Prefix.
*   Processes all `.zip` files in a specified input directory to an output directory.
*   Generates accurate `diff` output highlighting content changes, minimizing formatting noise.
*   Optionally validates modified bundles against the Apigee API using Google ADC.
*   Infers the proxy name for validation from the bundle filename (requires consistent naming).
*   Generates a detailed **Markdown report file**.
*   Supports overwriting existing output files (`--overwrite`).
*   Verbose console logging option (`-v`) for real-time progress and debugging.

## Prerequisites

1.  **Python:** Python 3.8 or higher recommended.
2.  **pip:** Python package installer.
3.  **Google Cloud SDK:** (`gcloud` command-line tool) installed and authenticated.
4.  **Application Default Credentials (ADC):** Configured for Google Cloud authentication. Run `gcloud auth application-default login` in your terminal and authenticate with a Google account that has permissions to validate Apigee APIs (e.g., Apigee API Admin role or custom role with `apigee.proxies.create`).
5.  **Required Python Libraries:** Install using pip.

## Installation

1.  **Clone or Download:** Get the script file : `tools/apigee-proxy-modifier-validator/modify_proxies.py`.
2.  **Install Dependencies:** Open your terminal in the script's directory and run:
    ```bash
    pip install -r tools/apigee-proxy-modifier-validator/requirements.txt
    ```

## Configuration

### 1. `policy.toml` Rules File (using XPath)

This file defines *how* to modify the XML files.

*   Create a file (e.g., `policy_lxml.toml`).
*   Define rules based on **XPath expressions** to select target XML nodes.
*   The root tag of the XML file (e.g., `<ServiceCallout>`, `<ProxyEndpoint>`) determines which section of the TOML file applies.

**Key TOML Fields per Rule:**

*   `[RootXmlElementTag]`: Section header matching the root XML tag.
*   `[RootXmlElementTag.RuleName]`: Unique name for the rule.
*   `xpath = "/path/to/element[@attr='val']"`: **Required.** An XPath 1.0 expression to select the target node(s). Use `.` for relative paths from root.
*   `target_type = "text" | "attribute"`: **Required.** What to modify (element's text or an attribute).
*   `attribute_name = "attr_name"`: **Required if `target_type="attribute"`.** The attribute name (no `@` prefix needed).
*   **Choose ONE Operation:**
    *   `to = "new_value"`: **Required for Set/Replace.** Final value.
    *   `from = "old_value"`: **Optional for Set/Replace & Conditional Prefix.** Value to replace or condition for prefixing. If omitted in Set/Replace, acts as a wildcard "set".
    *   `prefix = "prefix_string"`: **Required for Prefix & Conditional Prefix.** String to prepend.
    *   `suffix = "suffix_string"`: **Required for Suffix.** String to append.
*   **Exclusivity:** A rule cannot mix `prefix`, `suffix`, and `to`, *except* for `conditional_prefix` which requires both `prefix` and `from`.

### 2. Application Default Credentials (ADC)

Ensure ADC is set up before using `--validate`:

```bash
gcloud auth application-default login
```
Follow the browser prompts to authenticate. The account used needs Apigee permissions in the target Google Cloud project.

### Usage
Run the script from your terminal:
```bash
python modify_proxies.py --input-dir <path/to/input_bundles> \
                              --output-dir <path/to/output_bundles> \
                              --config-path <path/to/policy_lxml.toml> \
                              --report-file <path/to/output_report.md> \
                              [options]
```

**Options:**
Command-Line Arguments:
* --input-dir PATH: Required. Path to the directory containing the source .zip proxy bundles.
*  --output-dir PATH: Required. Path to the directory where modified .zip bundles will be saved. Must be different from the input directory.
* --config-path PATH: Required. Path to your .toml configuration file defining the modification rules.
* --report-file PATH: Required. Path where the output Markdown report will be saved.
* --validate: Optional. Enable validation of modified bundles using the Apigee API. Requires ADC to be configured.
* --org ORG_ID: Required if --validate is used. Your Apigee Organization ID.
*  --overwrite: Optional. If specified, existing files in the output directory with the same name as a bundle being processed will be overwritten. By default, existing files are skipped.
*  -v, --verbose: Optional. Enable detailed debug logging output.

### Usage Examples

Modify all bundles in a directory (no validation):
```bash
python modify_proxies.py --input-dir ./edge_proxies \
                              --output-dir ./hybrid_proxies \
                              --config-path ./rules_lxml.toml \
                              --report-file modification_report.md
```

Modify and Validate bundles:

```bash
python modify_proxies.py --input-dir ./edge_proxies \
                              --output-dir ./hybrid_proxies \
                              --config-path ./rules_lxml.toml \
                              --report-file validation_run.md \
                              --validate \
                              --org "your-apigee-project-id"
```

Modify and Validate with Overwrite and Verbose Logging:

```bash
python modify_proxies.py -v --overwrite \
                              --input-dir /path/to/input \
                              --output-dir /path/to/output \
                              --config-path ./prod_rules_lxml.toml \
                              --report-file prod_run_report.md \
                              --validate --org "my-prod-org"
```

### Validation Details
* Name Inference: Validation relies on inferring the proxy name from the .zip filename (removing suffixes like _revN, _vN). Ensure your filenames allow for correct inference. Adjust the infer_proxy_name function's regex if needed.
* API Call vs. Content Validity:
    * Success (API Call OK): The API request returned HTTP 2xx. The bundle might still have internal issues not detected by this basic validation call structure.
    * Success (API Issues Found): The API request returned HTTP 2xx, but the response body contained keywords like "error" or "validationerrors", suggesting Apigee found problems within the bundle content.
    * Failed (...): Indicates issues with the API call itself (Auth, Network, HTTP error), name inference, file access, or an unknown script error during validation.
* Check Logs: The "Validation Detail Snippet" provides a hint, but the full API response body and detailed error messages are only available in the script's console log output. Use -v for maximum detail.

### Output

1. Modified Bundles: .zip files containing the modified proxy structure are saved in the specified --output-dir.
2. Console Logs: Real-time progress, warnings, errors, and API responses (especially with -v).
3. Markdown Report (--report-file): A comprehensive report file containing:
    * Overall summary statistics.
    * A summary table showing the status for each processed bundle.
    * A detailed section for each bundle, including:
        * Modified status (Yes/No).
        * Validation result code (e.g., Success (API Call OK), Failed (Auth Error)).
        * A concise snippet extracted from the validation response, if relevant.
        * A list of modified files within that bundle, each followed by its diff output shown in a diff code block.


###  Important Notes & Caveats
* Backup: Always back up your original Apigee Edge bundles before running modifications.
* LXML Formatting: While lxml is good, minor formatting differences (e.g., self-closing tags, attribute order normalization) might still occur compared to the absolute original. Test thoroughly.
* TOML Rules: Carefully define your policy.toml rules. Incorrect paths or filters will prevent modifications. Test rules on a single bundle first.
* Validation Naming: Validation in directory mode depends heavily on accurate proxy name inference from filenames. Mismatched names will lead to validation failures.
* Error Handling: The script includes basic error handling, but complex bundle structures or unexpected TOML configurations might cause issues. Review logs if failures occur.
