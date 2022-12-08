#!/bin/sh
# Copyright 2021 Google LLC
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

###
### Deploy reference to apigee API (Edge) ###
###

if [ -z "$1" ] || [ "$1" = "--apigeeapi" ];then
    echo "[INFO] Deploying threat-protect reference to Apigee API (For Edge)"

    # deploy the API proxy
    sackmesser deploy --apigeeapi -o "$APIGEE_ORG" -e "$APIGEE_ENV" -u "$APIGEE_USER" -p "$APIGEE_PASS" -d "$SCRIPTPATH"
    # execute functional tests
    cd "$SCRIPTPATH" && npm i --no-fund && TEST_HOST="$APIGEE_ORG-$APIGEE_ENV.apigee.net" npm run test

fi

###
### Deploy reference to Google API (X/hybrid) ###
###

if [ -z "$1" ] || [ "$1" = "--googleapi" ];then
    echo "[INFO] Deploying Identitiy facade to Google API (For X/hybrid)"
    APIGEE_TOKEN="$(gcloud config config-helper --force-auth-refresh --format json | jq -r '.credential.access_token')";

    sackmesser deploy --googleapi -o "$APIGEE_X_ORG" -e "$APIGEE_X_ENV" -t "$APIGEE_TOKEN" -d "$SCRIPTPATH"
    cd "$SCRIPTPATH" && npm i --no-fund && TEST_HOST="$APIGEE_X_HOSTNAME" npm run test

fi