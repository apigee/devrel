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
import shutil
import sys
import json
import subprocess
from typing import Iterable


class GitClient:
    """Encapsulates Git operations."""
    
    @staticmethod
    def resolve_commits(commit_before: str, commit_after: str) -> tuple[str, str]:
        previous_commit = ""
        current_commit = commit_after

        if commit_before and commit_before == '0' * len(commit_before):
            print("Previous commit is zero. Comparing against an empty repository.")
            return "", current_commit

        try:
            git_rev_parse_proc = subprocess.run(
                ['git', 'rev-parse', '--verify', commit_before],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                text=True
            )
        except FileNotFoundError:
            print("Error: 'git' command not found. Ensure it is installed and in your PATH.", file=sys.stderr)
            sys.exit(1)

        if git_rev_parse_proc.returncode == 0:
            previous_commit = commit_before
        else:
            print(f"Commit reference '{commit_before}' not found. "
                  "Listing all tracked files as 'added'.")
            previous_commit = ""

        return previous_commit, current_commit

    @staticmethod
    def read_file_contents(commit_hash: str, file_path: str) -> str:
        return run_command_or_exit(
            ['git', 'show', f'{commit_hash}:{file_path}'],
            capture_output=True
        ).stdout

    @staticmethod
    def diff_hashes(hash_a: str, hash_b: str) -> subprocess.CompletedProcess:
       return run_command_or_exit(
            ['git', 'diff', '--name-status', hash_a, hash_b],
            capture_output=True
        )

    @staticmethod
    def list_files() -> subprocess.CompletedProcess:
        return run_command_or_exit(['git', 'ls-files'], capture_output=True)


def create_folder(folder_path):
    if os.path.exists(folder_path):
        shutil.rmtree(folder_path)

    os.makedirs(folder_path)
    return folder_path


def find_resource_type(file_name: str, available_types: Iterable[str]):
    for t in available_types:
        if file_name.startswith(t):
            return t
    return None


def write_to_file(file_path, contents):
    os.makedirs(os.path.dirname(file_path), exist_ok=True)

    json_str = json.dumps(contents, indent=4)
    with open(file_path, 'w') as f:
        f.write(json_str)

    print(f'\nWrote {file_path} with contents:\n{json_str}')


def run_command_or_exit(cmd_args, capture_output=False, text=True, cwd=None):
    stdout_setting = subprocess.PIPE if capture_output else None
    stderr_setting = subprocess.PIPE

    try:
        process = subprocess.run(
            cmd_args,
            check=True,
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

        stdout_msg = e.stdout.strip() if e.stdout and isinstance(e.stdout, str) else ""
        stderr_msg = e.stderr.strip() if e.stderr and isinstance(e.stderr, str) else ""

        if stdout_msg:
            print(f"Stdout: {stdout_msg}", file=sys.stderr)
        if stderr_msg:
            print(f"Stderr: {stderr_msg}", file=sys.stderr)
        sys.exit(e.returncode)


def merge(a, b):
    if isinstance(a, dict) and isinstance(b, dict):
        res = a.copy()
        for k, v in b.items():
            res[k] = merge(res[k], v) if k in res else v
        return res
    if isinstance(a, list) and isinstance(b, list):
        return a + b
    return b if b is not None else a
