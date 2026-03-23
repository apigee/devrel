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
import subprocess  # nosec B404


class MavenDeployer:
    """Isolates the subprocess calls to execute Maven commands."""

    def __init__(self, bearer=None, sa_path=None):
        self.bearer = bearer
        self.sa_path = sa_path

    def deploy(self, action: str, action_base_path: str, org: str, envs: set):
        config_dir = os.path.join(action_base_path, org)

        if envs:
            for e in envs:
                print(f"Running env {e} for org {org}...")
                self._run_mvn(action, config_dir, org, e)
        else:
            print(f"Running for org {org} (no specific env detected)...")
            self._run_mvn(action, config_dir, org)

    def _run_mvn(
        self, action: str, config_dir: str, org: str, env: str = None
    ):
        cmd = [
            "mvn",
            "install",
            f"-P{org}",
            f"-Dapigee.config.dir={config_dir}",
            f"-Dapigee.org={org}",
            f"-Dapigee.config.options={action}",
        ]

        if env:
            cmd.append(f"-Dapigee.env={env}")

        if self.bearer:
            cmd.append(f"-Dapigee.bearer={self.bearer}")

        if self.sa_path:
            cmd.append(f"-Dapigee.serviceaccount.file={self.sa_path}")

        try:
            subprocess.run(cmd, check=True)  # nosec B603
        except subprocess.CalledProcessError as e:
            print(f"Error running maven command: {e}", file=sys.stderr)
            sys.exit(1)


def get_affected_orgs_and_envs(
    action_base_path: str, affected_files: list
) -> dict:
    """
    Parses the affected files to find the involved organizations
    and environments.
    Returns a dictionary mapping organization names to a set of
    environment names.
    """
    org_env_map = {}  # org -> set(envs)

    for full_path in affected_files:
        rel_path = os.path.relpath(full_path, action_base_path)
        parts = rel_path.split(os.sep)

        org_name = parts[0]

        if not org_name or org_name == rel_path:
            continue

        envs = org_env_map.setdefault(org_name, set())
        if len(parts) > 2 and parts[1] == "env":
            envs.add(parts[2])

    return org_env_map


def process_files(
    output_base_path, resources_folder, confirm, bearer=None, sa_path=None
):

    actions = ["update", "delete"]

    # Strip trailing slash from resources_folder to ensure correct path joining
    resources_subpath = resources_folder.strip(os.sep)
    deployer = MavenDeployer(bearer, sa_path)

    for action in actions:
        action_base_path = os.path.join(
            output_base_path, action, resources_subpath
        )

        if not os.path.exists(action_base_path):
            if os.path.exists(os.path.join(output_base_path, action)):
                print(
                    f"No files found in {action_base_path} (subfolder empty)."
                )
            continue

        print(
            f"\nProcessing files in folder {action_base_path} "
            f"for action {action}"
        )

        affected_files = [
            os.path.join(root, file)
            for root, _, files in os.walk(action_base_path)
            for file in files
        ]

        if not affected_files:
            print(f"No files to process for {action}.")
            continue

        org_env_map = get_affected_orgs_and_envs(
            action_base_path, affected_files
        )

        print("--- Affected Orgs and Environments ---")
        if not org_env_map:
            print("No orgs/environments found.")
        else:
            for org, envs in org_env_map.items():
                envs_list = list(envs)
                print(
                    f"Org: {org}, Envs: {envs_list if envs_list else '(None)'}"
                )

        if confirm:
            print(
                f"--- Processing affected Orgs and Environments ({action}) ---"
            )
            for org, envs in org_env_map.items():
                deployer.deploy(action, action_base_path, org, envs)
        else:
            print(
                f"\n[Dry Run] The following structure would be processed "
                f"for action ({action}):"
            )
            try:
                subprocess.run( # nosec B603 B607
                    ["tree", action_base_path], check=False
                )  
            except FileNotFoundError:
                for f in affected_files:
                    print(f"  {f}")

            print("\nTo execute, call again with --confirm")
