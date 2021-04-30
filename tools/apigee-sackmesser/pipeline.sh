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

BASE_PATH="/sackmesser/v1/airports"

# Using another DevRel API Proxy for testing this tool
docker run apigee-sackmesser deploy \
  --apigeeapi \
  -g https://github.com/apigee/devrel/tree/main/references/cicd-pipeline \
  -n sackmesser-airports-v0 \
  -b "$BASE_PATH" \
  -u "$APIGEE_USER" \
  -p "$APIGEE_PASS" \
  -o "$APIGEE_ORG" \
  -e "$APIGEE_ENV"

(cd "$SCRIPT_FOLDER"/../../references/cicd-pipeline && \
  npm i && \
  TEST_HOST="$APIGEE_ORG-$APIGEE_ENV.apigee.net" \
  TEST_BASE_PATH="$BASE_PATH" \
  npm run integration-test)