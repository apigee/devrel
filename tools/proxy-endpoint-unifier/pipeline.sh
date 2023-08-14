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

SCRIPTPATH="$( cd "$(dirname "$0")" || exit >/dev/null 2>&1 ; pwd -P )"

# Clean up previously generated files
rm -rf "$SCRIPTPATH/input.properties"
rm -rf "$SCRIPTPATH/transformed"
rm -rf "$SCRIPTPATH/transformed_bundles"

# Generate input file
cat > "$SCRIPTPATH/input.properties" << EOF
[common]
input_apis=$SCRIPTPATH/test/api_bundles
processed_apis=$SCRIPTPATH/transformed
proxy_bundle_directory=$SCRIPTPATH/transformed_bundles
proxy_endpoint_count=4
debug=true

[validate]
enabled=true
gcp_project_id=$APIGEE_ORG
EOF

# Install Dependencies
python3 -m pip install -r "$SCRIPTPATH/requirements.txt"

# Generate Gcloud Acccess Token
export APIGEE_ACCESS_TOKEN=$(gcloud auth print-access-token)

# Execute Utility
python3 "$SCRIPTPATH/main.py"
