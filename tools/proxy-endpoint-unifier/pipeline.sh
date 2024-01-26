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
gcp_project_id=$APIGEE_X_ORG
EOF

# Install Dependencies
VENV_PATH="$SCRIPTPATH/venv"
python3 -m venv "$VENV_PATH"
# shellcheck source=/dev/null
. "$VENV_PATH/bin/activate"
pip install -r "$SCRIPTPATH/requirements.txt"

# Generate Gcloud Acccess Token
APIGEE_ACCESS_TOKEN="$(gcloud config config-helper --force-auth-refresh --format json | jq -r '.credential.access_token')"
export APIGEE_ACCESS_TOKEN

# Building API Proxy Bundle for Proxy containing more than 5 Proxy Endpoints
cd "$SCRIPTPATH/test/api_bundles/test-proxy"
rm -rf "$SCRIPTPATH/test/api_bundles/test-proxy/test.zip"
echo "Building original proxy bundle"
zip -q -r test.zip apiproxy/
cd "$SCRIPTPATH"

# Validating API Proxy Bundle for Proxy containing more than 5 Proxy Endpoints
echo "Validating the original proxy bundle"
python3 -c "import os, sys ,json; \
            from apigee import Apigee; \
            x = Apigee(os.getenv('APIGEE_X_ORG')); \
            x.set_auth_header(os.getenv('APIGEE_ACCESS_TOKEN')); \
            r=x.validate_api('apis','test/api_bundles/test-proxy/test.zip'); \
            print(json.dumps(r,indent=2))"
rm -rf "$SCRIPTPATH/test/api_bundles/test.zip"

# Running and Validating API Proxy Bundle after splitting the proxies
python3 "$SCRIPTPATH/main.py"

# deactivate venv & cleanup
deactivate
rm -rf "$VENV_PATH"
