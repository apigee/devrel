#!/bin/sh

# Copyright 2026 Google LLC
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

set -e

SCRIPTPATH="$(
    cd "$(dirname "$0")" || exit >/dev/null 2>&1
    pwd -P
)"

echo "==> Setting up a dummy git repository to exercise apigee-config-diff..."
TEMP_DIR="$(mktemp -d)"
cd "$TEMP_DIR"

# Initialize git
git init -b main
git config user.name "Apigee Config Diff Pipeline"
git config user.email "pipeline@example.com"

# Create first commit (initial state)
mkdir -p resources/org
cat <<'IN' > resources/org/targetServers.json
[
  {
    "name": "target-1",
    "host": "httpbin.org",
    "port": 443
  }
]
IN

cat <<'IN' > resources/org/kvms.json
[
  {
    "name": "my-kvm"
  }
]
IN

git add .
git commit -m "Initial commit with targets and kvm"

# Create second commit (add, modify, delete)
# 1. Modify existing target server list
cat <<'IN' > resources/org/targetServers.json
[
  {
    "name": "target-1",
    "host": "httpbin.org",
    "port": 80
  },
  {
    "name": "target-2",
    "host": "mocktarget.apigee.net",
    "port": 443
  }
]
IN

# 2. Delete a file
rm resources/org/kvms.json

# 3. Add a new file
cat <<'IN' > resources/org/apiProducts.json
[
  {
    "name": "test-product"
  }
]
IN

git add .
git commit -m "Second commit modifying configs"

echo "==> Setting up Python virtual environment..."
VENV_PATH="$TEMP_DIR/venv"
python3 -m venv "$VENV_PATH"
# shellcheck source=/dev/null
. "$VENV_PATH/bin/activate"

echo "==> Installing apigee-config-diff from $SCRIPTPATH..."
# Fallback to python execution if pip install fails in some restrictive environments
pip install --index-url https://pypi.org/simple/ "$SCRIPTPATH" || true

echo "==> Running apigee-config-diff tool..."
# Run tool with default (HEAD~1 vs HEAD) for folder 'resources' generating in 'output'
if command -v apigee-config-diff >/dev/null 2>&1; then
    apigee-config-diff --folder resources --output "$TEMP_DIR/output"
else
    export PYTHONPATH="$SCRIPTPATH/src"
    python3 -m apigee_config_diff.main --folder resources --output "$TEMP_DIR/output"
fi

echo "==> Inspecting output directory (Dry run)..."
if command -v tree >/dev/null 2>&1; then
    tree "$TEMP_DIR/output"
else
    find "$TEMP_DIR/output" -type f
fi

echo "==> Cleaning up resources..."
deactivate
rm -rf "$TEMP_DIR"
rm -rf "$SCRIPTPATH/src/apigee_config_diff.egg-info"

echo "==> Pipeline finished successfully."
