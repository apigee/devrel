# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""
Module for diffing Apigee configurations.
Provides functions to recursively diff dictionaries and lists of objects.
"""

import sys
from typing import Any, Dict, List, Set, Tuple, Union, TypedDict

if sys.version_info >= (3, 10):
    from typing import TypeAlias
else:  # pragma: no cover
    from typing_extensions import TypeAlias

JSONValue: TypeAlias = Union[Dict[str, Any], List[Any], str, int, float, bool, None]


class DiffResult(TypedDict):
    """Type definition for the diff result."""

    added: JSONValue
    deleted: JSONValue
    modified: JSONValue


IdentificationMap: TypeAlias = Dict[Any, Dict[str, Any]]


def _transform_identification(
    identifier: str, content: List[Dict[str, Any]]
) -> IdentificationMap:
    """
    Transforms a list of dictionaries into a dictionary indexed by the given identifier.

    Args:
        identifier: The key to use as the index.
        content: The list of dictionaries to transform.

    Returns:
        A dictionary where keys are the values of the identifier in each item.

    Raises:
        ValueError: If the identifier is empty.
        KeyError: If an item in the list is missing the required identifier.
    """
    if not identifier:
        raise ValueError("Identifier cannot be empty.")

    identified_content = {}
    for index, item in enumerate(content):
        try:
            val = item[identifier]
            identified_content[val] = item
        except (KeyError, TypeError):
            raise KeyError(
                f"Item at index {index} is missing the required identifier '{identifier}'. "
                f"Item content: {item}"
            ) from None
    return identified_content


def _diff_list(
    identifier: str, before_content: List[Any], after_content: List[Any]
) -> DiffResult:
    """
    Diffs two lists of dictionaries based on a unique identifier.

    Args:
        identifier: The key used to identify items across lists.
        before_content: The original list.
        after_content: The new list.

    Returns:
        A dictionary with 'added', 'deleted', and 'modified' lists.
    """
    # Transform list to dict using identifier as key
    before_identified = _transform_identification(identifier, before_content)
    after_identified = _transform_identification(identifier, after_content)

    results: DiffResult = {"added": [], "deleted": [], "modified": []}

    for key, val_after in after_identified.items():
        if key in before_identified:
            val_before = before_identified[key]
            if val_after != val_before:
                results["modified"].append(val_after)  # type: ignore
        else:
            results["added"].append(val_after)  # type: ignore

    for key, val_before in before_identified.items():
        if key not in after_identified:
            results["deleted"].append(val_before)  # type: ignore

    return results


def _collect_diff_results(
    target_results: Dict[str, Dict[str, Any]],
    key: str,
    diff_data: DiffResult,
) -> None:
    """
    Helper to collect non-empty diff results into target dictionaries.

    Args:
        target_results: The dictionary containing 'added', 'deleted', 'modified' dicts.
        key: The key associated with the diff data.
        diff_data: The diff results to collect.
    """
    if diff_data["added"]:
        target_results["added"][key] = diff_data["added"]
    if diff_data["deleted"]:
        target_results["deleted"][key] = diff_data["deleted"]
    if diff_data["modified"]:
        target_results["modified"][key] = diff_data["modified"]


def _diff_dict(
    identifier: str, before_content: Dict[str, Any], after_content: Dict[str, Any]
) -> DiffResult:
    """
    Recursively diffs two dictionaries.

    Args:
        identifier: The key used to identify items in nested lists.
        before_content: The original dictionary.
        after_content: The new dictionary.

    Returns:
        A dictionary with 'added', 'deleted', and 'modified' sub-dictionaries.
    """
    results: DiffResult = {"added": {}, "deleted": {}, "modified": {}}

    for key, val_after in after_content.items():
        if key in before_content:
            val_before = before_content[key]

            if isinstance(val_before, list) and isinstance(val_after, list):
                # Check if it's a list of dictionaries
                is_list_of_dicts = any(isinstance(i, dict) for i in val_before) or any(
                    isinstance(i, dict) for i in val_after
                )

                if is_list_of_dicts:
                    list_diff = _diff_list(identifier, val_before, val_after)
                    _collect_diff_results(results, key, list_diff)  # type: ignore
                elif val_before != val_after:
                    results["modified"][key] = val_after  # type: ignore
            elif isinstance(val_before, dict) and isinstance(val_after, dict):
                dict_diff = _diff_dict(identifier, val_before, val_after)
                _collect_diff_results(results, key, dict_diff)  # type: ignore
            elif val_before != val_after:
                results["modified"][key] = val_after  # type: ignore
        else:
            results["added"][key] = val_after  # type: ignore

    for key, val_before in before_content.items():
        if key not in after_content:
            results["deleted"][key] = val_before  # type: ignore

    return results


def diff(
    before_content: JSONValue, after_content: JSONValue, identifier: str
) -> DiffResult:
    """
    Main entry point for diffing two configurations.

    Args:
        before_content: The original configuration (list or dict).
        after_content: The new configuration (list or dict).
        identifier: The key used to identify items in lists.

    Returns:
        A DiffResult containing added, deleted, and modified changes.

    Raises:
        ValueError: If inputs are lists but identifier is not provided.
        TypeError: If contents are not of supported types or mixed incorrectly.
    """
    # Handle dicts
    if isinstance(before_content, dict) and isinstance(after_content, dict):
        return _diff_dict(identifier, before_content, after_content)

    # Handle lists
    if isinstance(before_content, list) and isinstance(after_content, list):
        if not identifier:
            raise ValueError("Identifier is needed to diff lists.")
        return _diff_list(identifier, before_content, after_content)

    raise TypeError(
        "Invalid contents to diff. Both must be lists or both must be dicts."
    )
