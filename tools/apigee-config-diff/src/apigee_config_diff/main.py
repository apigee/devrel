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

import argparse
from .diff.check import detect_changes, write_temporary_files
from .diff.util import GitClient
from .diff.process import process_files


def parse_args():
    parser = argparse.ArgumentParser(
        description="Apigee Config Diff Generator and Deployer"
    )

    parser.add_argument(
        "--commit-before",
        help="Previous commit hash (default: HEAD~1)",
        default="HEAD~1",
    )
    parser.add_argument(
        "--current-commit",
        help="Current commit hash (default: HEAD)",
        default="HEAD",
    )
    parser.add_argument(
        "--folder",
        help="Files folder from repo root to diff (default: resources)",
        default="resources",
    )
    parser.add_argument(
        "--output",
        help="Output folder for generated trees (default: output)",
        default="output",
    )
    parser.add_argument(
        "--confirm",
        action="store_true",
        help="Execute the Maven plugin (apply changes)",
    )
    parser.add_argument(
        "--bearer", help="Apigee bearer token (optional)", default=None
    )
    parser.add_argument(
        "--sa-path",
        help="Path to service account key file (optional)",
        default=None,
    )

    return parser.parse_args()


def main():
    args = parse_args()

    previous_commit, current_commit = GitClient.resolve_commits(
        args.commit_before, args.current_commit
    )

    # Find files added, deleted or modified
    added_files, deleted_files, modified_files = detect_changes(
        previous_commit, current_commit, args.folder
    )

    # Write the files to be processed
    write_temporary_files(
        added_files,
        deleted_files,
        modified_files,
        previous_commit,
        current_commit,
        args.output,
    )

    # Process (Plan or Apply)
    process_files(
        args.output, args.folder, args.confirm, args.bearer, args.sa_path
    )


if __name__ == "__main__":  # pragma: no cover
    main()
