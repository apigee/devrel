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

import os
import sys
import json

from .diff import diff
from .util import (
    GitClient,
    write_to_file,
    find_resource_type,
    create_folder,
    merge,
)

RESOURCES_ID = {
    "flowhooks": "flowHookPoint",
    "references": "name",
    "targetServers": "name",
    "keystores": "name",
    "aliases": "alias",
    "apiProducts": "name",
    "developers": "email",
    "developerApps": "name",
    "kvm": "name",
    "cache": "name",
    "appGroup": "name",
    "caches": "name",
    "appGroups": "name",
    "reports": "name",
}


def detect_changes(previous_commit, current_commit, resources_base_path):

    print("==================================================")
    print("Detecting File Changes")
    print("==================================================")
    effective_previous_commit_msg = (
        previous_commit if previous_commit else "N/A (listing all as new)"
    )
    print(f"  Previous Commit (Effective): {effective_previous_commit_msg}")
    print(f"  Current Commit: {current_commit}")
    print("")

    added_files = []
    modified_files = []
    deleted_files = []

    if not previous_commit:
        result = GitClient.list_files()
        if result.stdout:
            for file_path in result.stdout.strip().split("\n"):
                if file_path and file_path.startswith(resources_base_path):
                    added_files.append(file_path)
    else:
        result = GitClient.diff_hashes(previous_commit, current_commit)
        diff_output = result.stdout.strip() if result.stdout else ""

        if diff_output:
            for line in diff_output.split("\n"):
                if not line:
                    continue
                parts = line.split("\t")
                status_char = parts[0][0]
                path_old = parts[1]
                path_new = parts[2] if len(parts) > 2 else None

                if status_char == "A":
                    if path_old.startswith(resources_base_path):
                        added_files.append(path_old)
                elif status_char == "M":
                    if path_old.startswith(resources_base_path):
                        modified_files.append(path_old)
                elif status_char == "D":
                    if path_old.startswith(resources_base_path):
                        deleted_files.append(path_old)
                elif status_char == "R":
                    if not path_new:
                        print(
                            f"Warning: Rename status '{parts[0]}' "
                            f"for '{path_old}' "
                            f"missing new path.",
                            file=sys.stderr,
                        )
                        continue
                    if path_old.startswith(resources_base_path):
                        deleted_files.append(path_old)
                    if path_new.startswith(resources_base_path):
                        added_files.append(path_new)
                elif status_char == "C":
                    if not path_new:
                        print(
                            f"Warning: Copy status '{parts[0]}' "
                            f"for '{path_old}' "
                            f"missing new path.",
                            file=sys.stderr,
                        )
                        continue
                    if path_new.startswith(resources_base_path):
                        added_files.append(path_new)
                else:
                    print(
                        f"Unknown git status: {parts[0]} for file {path_old}",
                        file=sys.stderr,
                    )

    print("--- Summary of Changes ---")

    print(f"Added files ({len(added_files)}):")
    if added_files:
        for f_path in added_files:
            print(f"  {f_path}")

    print(f"Deleted files ({len(deleted_files)}):")
    if deleted_files:
        for f_path in deleted_files:
            print(f"  {f_path}")

    print(f"Modified files ({len(modified_files)}):")
    if modified_files:
        for f_path in modified_files:
            print(f"  {f_path}")

    return added_files, deleted_files, modified_files


def calculate_file_diffs(
    added_files, deleted_files, modified_files, previous_commit, current_commit
):
    """
    Calculates the diffs and determines what content needs to be written
    for updates and deletions.
    Returns two dictionaries: files_to_update, files_to_delete containing
    file_path to json mapping.
    """
    files_to_update = {}
    files_to_delete = {}

    for f_path in added_files:
        file_contents = GitClient.read_file_contents(current_commit, f_path)
        try:
            files_to_update[f_path] = json.loads(file_contents)
        except json.JSONDecodeError as e:
            print(
                f"Warning: Failed to parse JSON in added file {f_path}: {e}",
                file=sys.stderr,
            )

    for f_path in deleted_files:
        file_contents = GitClient.read_file_contents(previous_commit, f_path)
        try:
            files_to_delete[f_path] = json.loads(file_contents)
        except json.JSONDecodeError as e:
            print(
                f"Warning: Failed to parse JSON in deleted file {f_path}: {e}",
                file=sys.stderr,
            )

    for f_path in modified_files:
        previous_file_contents = GitClient.read_file_contents(
            previous_commit, f_path
        )
        current_file_contents = GitClient.read_file_contents(
            current_commit, f_path
        )

        file_name = os.path.basename(f_path)
        resource_type = find_resource_type(file_name, RESOURCES_ID)

        try:
            if resource_type:
                diff_elements = diff(
                    json.loads(previous_file_contents),
                    json.loads(current_file_contents),
                    RESOURCES_ID[resource_type],
                )

                print(f"Diff of elements inside {f_path}:")
                print(json.dumps(diff_elements, indent=4))

                added_and_modified = merge(
                    diff_elements["added"], diff_elements["modified"]
                )

                if added_and_modified:
                    files_to_update[f_path] = added_and_modified

                if diff_elements["deleted"]:
                    files_to_delete[f_path + ".delete"] = diff_elements[
                        "deleted"
                    ]
            else:
                print(
                    f"Unknown resource type for {f_path}. Deploying full file."
                )
                files_to_update[f_path] = json.loads(current_file_contents)
        except json.JSONDecodeError as e:
            print(
                f"Warning: Failed to parse JSON "
                f"in modified file {f_path}: {e}",
                file=sys.stderr,
            )

    return files_to_update, files_to_delete


def write_temporary_files(
    added_files,
    deleted_files,
    modified_files,
    previous_commit,
    current_commit,
    tmp_base_path,
):
    """
    Resolves the diffs and writes the resulting temporary files to disk.
    """
    files_to_update, files_to_delete = calculate_file_diffs(
        added_files,
        deleted_files,
        modified_files,
        previous_commit,
        current_commit,
    )

    update_folder = create_folder(f"{tmp_base_path}/update")
    delete_folder = create_folder(f"{tmp_base_path}/delete")

    for f_path, contents in files_to_update.items():
        write_to_file(os.path.join(update_folder, f_path), contents)

    for f_path, contents in files_to_delete.items():
        write_to_file(os.path.join(delete_folder, f_path), contents)
