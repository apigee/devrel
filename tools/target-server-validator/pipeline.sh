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

gcloud components install beta --quiet # as the cloud-sdk image no longer has this
bash "$SCRIPTPATH/test/create_notification_channel.sh" "$APIGEE_X_ORG" "$SCRIPTPATH/channel.txt"
NOTIFICATION_CHANNEL_IDS=$(cat "$SCRIPTPATH/channel.txt")
echo "Created Notification Channel Id - $NOTIFICATION_CHANNEL_IDS"

bash "$SCRIPTPATH/callout/build_java_callout.sh"

# Clean up previously generated files
rm -rf "$SCRIPTPATH/export"
rm -rf "$SCRIPTPATH/report*"

# Generate input file
NOTIFICATION_CHANNEL_IDS=$NOTIFICATION_CHANNEL_IDS envsubst <"$SCRIPTPATH/input.properties" >"$SCRIPTPATH/generated.properties"

# Generate optional input csv file
cat >"$SCRIPTPATH/input.csv" <<EOF
HOST,PORT
httpbin.org
httpbin.org,443
domaindoesntexist.apigee.tom
smtp.gmail.com,465
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

# Running the Target Server Validator
cd "$SCRIPTPATH"

python3 main.py --onboard --input "$SCRIPTPATH/generated.properties"

python3 main.py --scan --input "$SCRIPTPATH/generated.properties"

python3 main.py --monitor --input "$SCRIPTPATH/generated.properties"

python3 main.py --offboard --input "$SCRIPTPATH/generated.properties"

# Display Report
cat "$SCRIPTPATH/report.md"

# cleanup files and notification channel
bash "$SCRIPTPATH/test/delete_notification_channel.sh" "$APIGEE_X_ORG" "$NOTIFICATION_CHANNEL_IDS"
rm -f "$SCRIPTPATH/channel.txt"
rm -f "$SCRIPTPATH/scan_output.json"

# deactivate venv & cleanup
deactivate
rm -rf "$VENV_PATH"
