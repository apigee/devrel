#!/bin/bash

# Copyright 2021 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# <http://www.apache.org/licenses/LICENSE-2.0>
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e

SCRIPT_FOLDER=$( (cd "$(dirname "$0")" && pwd ))

# validate docker build
"$SCRIPT_FOLDER"/build.sh -t apigee-sackmesser

PATH="$PATH:$SCRIPT_FOLDER/bin"
APIGEE_X_TOKEN=$(gcloud auth print-access-token)
unset APIGEE_TOKEN

# Test Sackmesser Deploy
# (Using another DevRel API Proxy for testing this tool)

# Sackmesser CLI
BASE_PATH="/sackmesser/v1/cli"

sackmesser deploy \
  --googleapi \
  -d "$SCRIPT_FOLDER"/../../references/cicd-pipeline \
  -n sackmesser-cli-v0 \
  -b "$BASE_PATH" \
  -t "$APIGEE_X_TOKEN" \
  -o "$APIGEE_X_ORG" \
  -e "$APIGEE_X_ENV"

(cd "$SCRIPT_FOLDER"/../../references/cicd-pipeline && \
  npm i && \
  TEST_HOST="$APIGEE_X_HOSTNAME" \
  TEST_BASE_PATH="$BASE_PATH" \
  npm run integration-test)

# Sackmesser Docker Container
BASE_PATH="/sackmesser/v1/docker"

docker run apigee-sackmesser deploy \
  --apigeeapi \
  --github https://github.com/apigee/devrel/tree/main/references/cicd-pipeline \
  --name sackmesser-docker-v0 \
  --base-path "$BASE_PATH" \
  --username "$APIGEE_USER" \
  --password "$APIGEE_PASS" \
  --organization "$APIGEE_ORG" \
  --environment "$APIGEE_ENV"

(cd "$SCRIPT_FOLDER"/../../references/cicd-pipeline && \
  npm i && \
  TEST_HOST="$APIGEE_ORG-$APIGEE_ENV.apigee.net" \
  TEST_BASE_PATH="$BASE_PATH" \
  npm run integration-test)

# Test Sackmesser Await
# (Test readiness of the deployed API proxy)
sackmesser await --googleapi -t "$APIGEE_X_TOKEN" proxy "sackmesser-cli-v0"

docker run apigee-sackmesser await --apigeeapi --username "$APIGEE_USER" \
  --password "$APIGEE_PASS" --organization "$APIGEE_ORG" \
  --environment "$APIGEE_ENV" proxy "sackmesser-docker-v0"

# Test Sackmesser List
# (List all proxies to find the previously deployed API proxy)
sackmesser list --googleapi -t "$APIGEE_X_TOKEN" "organizations/$APIGEE_X_ORG/apis" | grep "sackmesser-cli-v0"

docker run apigee-sackmesser list --apigeeapi -u "$APIGEE_USER" -p "$APIGEE_PASS" "organizations/$APIGEE_ORG/apis" | grep "sackmesser-docker-v0"

# Test Sackmesser Export
sackmesser export --googleapi -o "$APIGEE_X_ORG" -t "$APIGEE_X_TOKEN"
if [ ! -d  "$APIGEE_X_ORG/proxies/sackmesser-cli-v0" ]; then
  echo "export failed"
  exit 1
fi
rm -rf "$APIGEE_X_ORG"

docker run --entrypoint /bin/bash apigee-sackmesser -c "sackmesser export --apigeeapi -u $APIGEE_USER -p $APIGEE_PASS -o $APIGEE_ORG && ls $APIGEE_ORG/proxies/sackmesser-docker-v0"

# Test Sackmesser Clean
sackmesser clean proxy sackmesser-docker-v0 --apigeeapi -u "$APIGEE_USER" -p "$APIGEE_PASS" -o "$APIGEE_ORG" --quiet
proxiesremaining=$(sackmesser list --apigeeapi -u "$APIGEE_USER" -p "$APIGEE_PASS" "organizations/$APIGEE_ORG/apis")
if [ "$(echo "$proxiesremaining" | jq 'map(select(. == "sackmesser-docker-v0"))')" != "[]" ];then
  echo "failed to delete"
  exit 1
fi

docker run apigee-sackmesser clean proxy sackmesser-cli-v0 --googleapi -t "$APIGEE_X_TOKEN" -o "$APIGEE_X_ORG" --quiet

proxiesremaining=$(sackmesser list --googleapi -t "$APIGEE_X_TOKEN" "organizations/$APIGEE_X_ORG/apis")
if [ "$(echo "$proxiesremaining" | jq 'map(select(. == "sackmesser-cli-v0"))')" != "[]" ];then
  echo "failed to delete proxy"
  exit 1
fi