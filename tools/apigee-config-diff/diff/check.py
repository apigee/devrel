import os
import sys
import json

from .diff import diff
from .util import git_diff_hashes, run_command_or_exit, write_to_file, find_resource_type, create_folder, read_git_file_contents, merge


RESOURCES_ID = {
    "flowhooks": "flowHookPoint",
    "references": "name",
    "targetServers": "name",
    "keystores": "name",
    "aliases": "alias",
    "apiProducts": "name",
    "developers": "email",
    "developerApps": "name"
}


def detect_changes(previous_commit, current_commit, resources_base_path):

    print("==================================================")
    print("Detecting File Changes")
    print("==================================================")
    effective_previous_commit_msg = previous_commit if previous_commit else "N/A (listing all as new)"
    print(f"  Previous Commit (Effective): {effective_previous_commit_msg}")
    print(f"  Current Commit: {current_commit}")
    print("")

    added_files = []
    modified_files = []
    deleted_files = []
    renamed_or_copied_files = []

    if not previous_commit:
        # Very first commit scenario - list all tracked files
        # _run_git_command_or_exit will handle errors if `git ls-files` fails
        result = run_command_or_exit(['git', 'ls-files'], capture_output=True)
        if result.stdout: # result.stdout should be a string
            for file_path in result.stdout.strip().split('\n'):
                if file_path:  # Ensure not an empty line
                    added_files.append(file_path)
    else:
        # Use git diff to get file statuses
        # _run_git_command_or_exit handles errors if `git diff` fails (e.g. invalid commit SHAs)
        result = git_diff_hashes(previous_commit, current_commit)
        diff_output = result.stdout.strip() if result.stdout else ""

        if diff_output:
            for line in diff_output.split('\n'):
                parts = line.split('\t')
                status_code = parts[0]  # e.g., A, M, D, R100, C075
                path_old = parts[1]
                # path_new is only present for R (Rename) and C (Copy) types
                path_new = parts[2] if len(parts) > 2 else None

                # Skip if it's not an Apigee resource file
                if not path_old.startswith(resources_base_path):
                    continue

                if status_code.startswith('A'):
                    added_files.append(path_old)
                elif status_code.startswith('M'):
                    modified_files.append(path_old)
                elif status_code.startswith('D'):
                    deleted_files.append(path_old)
                elif status_code.startswith('R'):  # Renamed
                    if path_new is None: # Should not happen with R status
                        print(f"Warning: Rename status '{status_code}' for '{path_old}' missing new path.", file=sys.stderr)
                        continue
                    deleted_files.append(path_old) # Old path is considered deleted
                    added_files.append(path_new)   # New path is considered added
                    renamed_or_copied_files.append(f"{path_old} -> {path_new} (Renamed)")
                elif status_code.startswith('C'):  # Copied
                    if path_new is None: # Should not happen with C status
                        print(f"Warning: Copy status '{status_code}' for '{path_old}' missing new path.", file=sys.stderr)
                        continue
                    added_files.append(path_new) # New path is considered added
                    renamed_or_copied_files.append(f"{path_old} -> {path_new} (Copied)")
                else:
                    print(f"Unknown git status: {status_code} for file {path_old}", file=sys.stderr)

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


def write_temporary_files(added_files, deleted_files, modified_files, previous_commit, current_commit, tmp_base_path):

    # Base folder for create/update/delete Apigee resources
    update_folder = create_folder(f'{tmp_base_path}/update')
    delete_folder = create_folder(f'{tmp_base_path}/delete')

    # New files on commit
    if added_files:
        for f_path in added_files:
            file_contents = read_git_file_contents(current_commit, f_path)
            write_to_file(os.path.join(update_folder, f_path), json.loads(file_contents))

    # Delete files on commit
    if deleted_files:
        for f_path in deleted_files:
            file_contents = read_git_file_contents(previous_commit, f_path)
            write_to_file(os.path.join(delete_folder, f_path), json.loads(file_contents))

    # For modified files, apply a smarter diff logic
    if modified_files:
        for f_path in modified_files:

            # How this file was before the commit
            previous_file_contents = read_git_file_contents(previous_commit, f_path)

            # And the current version
            current_file_contents = read_git_file_contents(current_commit, f_path)

            # Find out which Apigee resource it is (targetServer, alias, etc...)
            file_name = os.path.basename(f_path)
            type = find_resource_type(file_name, RESOURCES_ID.keys())

            if type:
                diff_elements = diff(json.loads(previous_file_contents), json.loads(current_file_contents), RESOURCES_ID[type])

                print(f"Diff of elements inside {f_path}:")
                print(json.dumps(diff_elements, indent=4))

                added_and_modified = merge(diff_elements['added'], diff_elements['modified'])
                
                if len(added_and_modified) > 0:
                    write_to_file(os.path.join(update_folder, f_path), added_and_modified)

                # Add a new file for deletion, with deleted elements from modified file
                if len(diff_elements['deleted']) > 0:
                    write_to_file(os.path.join(delete_folder, f'{f_path}.delete'), diff_elements['deleted'])
