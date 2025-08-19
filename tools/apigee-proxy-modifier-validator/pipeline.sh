#!/bin/sh

# Copyright 2023 Google LLC
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

# Install Dependencies
VENV_PATH="$SCRIPTPATH/venv"
python3 -m venv "$VENV_PATH"
# shellcheck source=/dev/null
. "$VENV_PATH/bin/activate"
pip install -r "$SCRIPTPATH/requirements.txt"

# Running the Target Server Validator
cd "$SCRIPTPATH"
INPUT_PATH="$SCRIPTPATH/test"
OUTPUT_PATH="$SCRIPTPATH/output"

python modify_proxies.py -v --overwrite \
        --input-dir "$INPUT_PATH" \
        --output-dir "$OUTPUT_PATH" \
        --config-path "$SCRIPTPATH/policy.toml" \
        --report-file "$SCRIPTPATH/report.md" \
        --validate --org "$APIGEE_X_ORG"

# Display Report
cat "$SCRIPTPATH/report.md"

# deactivate venv & cleanup
deactivate
rm -rf "$VENV_PATH" || echo "OK"
rm -rf "$OUTPUT_PATH" || echo "OK"
rm -rf "$SCRIPTPATH/report.md" || echo "OK"
