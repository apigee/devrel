#!/bin/sh

# Copyright 2020 Google LLC
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

SCRIPTPATH=$( (cd "$(dirname "$0")" && pwd ))

(cd "$SCRIPTPATH" && npm i --no-fund)
(cd "$SCRIPTPATH" && npm run unit-test)

echo "Testing on Apigee Edge"
sackmesser deploy --apigeeapi -d "$SCRIPTPATH" \
  -u "$APIGEE_USER" -p "$APIGEE_PASS" -o "$APIGEE_ORG" -e "$APIGEE_ENV" \
  -n js-callout-v1

(cd "$SCRIPTPATH" && TEST_HOST="$APIGEE_ORG-$APIGEE_ENV.apigee.net" npm run integration-test)

echo "Testing on Apigee X"
APIGEE_TOKEN="$(gcloud config config-helper --force-auth-refresh --format json | jq -r '.credential.access_token')"
sackmesser deploy --googleapi -d "$SCRIPTPATH" \
  -t "$APIGEE_TOKEN" -o "$APIGEE_X_ORG" -e "$APIGEE_X_ENV" \
  -n js-callout-v1

(cd "$SCRIPTPATH" && TEST_HOST="$APIGEE_X_HOSTNAME" npm run integration-test)
