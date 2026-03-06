import os
import shutil
import sys
import json
import subprocess
import re
from typing import Iterable

def resolve_commits(commit_before, commit_after):
    previous_commit = ""
    current_commit = commit_after

    if re.fullmatch(r'0+', commit_before):
        print("Previous commit is all zeros (new branch or first push to PR).")
        try:
            # Try to see if HEAD~1 exists.
            git_rev_parse_proc = subprocess.run(
                ['git', 'rev-parse', '--verify', 'HEAD~1'],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                text=True
            )

            if git_rev_parse_proc.returncode == 0:
                previous_commit = "HEAD~1"
                print("Comparing against parent of current commit (HEAD~1).")
            else:
                print("This appears to be the first commit. Listing all tracked files as 'added'.")
                previous_commit = ""  # Will be handled to list all files

        except FileNotFoundError:
            print("Error: 'git' command not found. Ensure it is installed and in your PATH.", file=sys.stderr)
            sys.exit(1)
    else:
        previous_commit = commit_before

    return previous_commit, current_commit


def read_git_file_contents(commit_hash, file_path):
    return run_command_or_exit(
        ['git', 'show', f'{commit_hash}:{file_path}'],
        capture_output=True
    ).stdout


def git_diff_hashes(hash_a, hash_b):
   return run_command_or_exit(
        ['git', 'diff', '--name-status', hash_a, hash_b],
        capture_output=True
    )


def create_folder(folder_path):
    if os.path.exists(folder_path):
        shutil.rmtree(folder_path)

    # Create the tmp folder to run
    os.makedirs(folder_path)

    return folder_path


def find_resource_type(file_name: str, available_types: Iterable[str]):
    for t in available_types:
        if file_name.startswith(t):
            return t

    return None


def write_to_file(file_path, contents):

    # Create all missing folders up to the file
    os.makedirs(os.path.dirname(file_path), exist_ok=True)

    with open(file_path, 'w') as f:
        json.dump(contents, f, indent=4)

    print(f'\nWrote {file_path} with contents:\n{json.dumps(contents, indent=4)}')


def run_command_or_exit(cmd_args, capture_output=False, text=True, cwd=None):
    """
    Runs a command. If it fails (non-zero exit code or command not found),
    prints an error message to stderr and exits the script.
    """
    stdout_setting = subprocess.PIPE if capture_output else None
    stderr_setting = subprocess.PIPE

    try:
        process = subprocess.run(
            cmd_args,
            check=True,  # Raises CalledProcessError for non-zero exit codes
            text=text,
            stdout=stdout_setting,
            stderr=stderr_setting,
            cwd=cwd
        )
        return process
    except FileNotFoundError:
        print(f"Error: Command '{cmd_args[0]}' not found. "
              "Ensure git is installed and in your PATH.", file=sys.stderr)
        sys.exit(1)
    except subprocess.CalledProcessError as e:
        print(f"Error executing: {' '.join(e.cmd)}", file=sys.stderr)
        print(f"Return code: {e.returncode}", file=sys.stderr)

        # Decode stdout/stderr if they are bytes (e.g. if text=False was used, though not here)
        stdout_msg = e.stdout.strip() if e.stdout and isinstance(e.stdout, str) else ""
        stderr_msg = e.stderr.strip() if e.stderr and isinstance(e.stderr, str) else ""

        if stdout_msg: # Should be empty if command failed before producing stdout
            print(f"Stdout: {stdout_msg}", file=sys.stderr)
        if stderr_msg: # This usually contains the git error message
            print(f"Stderr: {stderr_msg}", file=sys.stderr)
        sys.exit(e.returncode)
