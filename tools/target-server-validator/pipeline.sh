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

bash "$SCRIPTPATH/callout/build_java_callout.sh"

# Clean up previously generated files
rm -rf "$SCRIPTPATH/input.properties"
rm -rf "$SCRIPTPATH/export"
rm -rf "$SCRIPTPATH/report*"

# Generate input file
cat > "$SCRIPTPATH/input.properties" << EOF
[source]
baseurl=https://apigee.googleapis.com/v1
org=$APIGEE_X_ORG
auth_type=oauth

[target]
baseurl=https://apigee.googleapis.com/v1
org=$APIGEE_X_ORG
auth_type=oauth

[csv]
file=input.csv
default_port=443

[validation]
check_csv=true
check_proxies=true
proxy_export_dir=export
skip_proxy_list=
api_env=$APIGEE_X_ENV
api_name=target_server_validator
api_force_redeploy=true
vhost_domain_name=$APIGEE_X_HOSTNAME
vhost_ip=
report_format=md
EOF

# Generate optional input csv file
cat > "$SCRIPTPATH/input.csv" << EOF
HOST,PORT
httpbin.org
httpbin.org,443
mocktarget.apigee.tom
smtp.gmail.com,465
EOF

# Install Dependencies
python3 -m pip install -r "$SCRIPTPATH/requirements.txt"

# Generate Gcloud Acccess Token
APIGEE_ACCESS_TOKEN="$(gcloud config config-helper --force-auth-refresh --format json | jq -r '.credential.access_token')"
export APIGEE_ACCESS_TOKEN

# Running the Target Server Validator
cd "$SCRIPTPATH"

python3 main.py

# Display Report
cat "$SCRIPTPATH/report.md"
