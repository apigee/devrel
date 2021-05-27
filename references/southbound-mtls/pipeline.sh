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

SCRIPTPATH="$( cd "$(dirname "$0")" || exit >/dev/null 2>&1 ; pwd -P )"

TEMP_DIR="$SCRIPTPATH"/tmp
mkdir -p "$SCRIPTPATH"/tmp
curl https://badssl.com/certs/badssl.com-client.p12 -o "$TEMP_DIR"/badssl.com-client.p12

cp "$SCRIPTPATH"/edge.template.json "$SCRIPTPATH"/edge.json

export PATH="$PATH:$SCRIPTPATH/../../tools/apigee-sackmesser/bin"

# Apigee Edge

TEST_BASEPATH='/badssl/v0'
sed -i.bak "s/@ENV_NAME@/$APIGEE_ENV/g" "$SCRIPTPATH"/edge.json && rm "$SCRIPTPATH"/edge.json.bak
sed -i.bak "s|@CERT_PATH@|$TEMP_DIR/badssl.com-client.p12|g" "$SCRIPTPATH"/edge.json && rm "$SCRIPTPATH"/edge.json.bak

sackmesser deploy \
--apigeeapi \
--description "mTLS badssl demo" \
-d "$SCRIPTPATH" \
-n mtls-demo \
-b "$TEST_BASEPATH" \
-u "$APIGEE_USER" \
-p "$APIGEE_PASS" \
-o "$APIGEE_ORG" \
-e "$APIGEE_ENV"

TEST_HOST="$APIGEE_ORG-$APIGEE_ENV.apigee.net"
(cd "$SCRIPTPATH" && TEST_HOST=$TEST_HOST TEST_BASEPATH=$TEST_BASEPATH npm run test)

# Apigee X

APIGEE_TOKEN=$(gcloud auth print-access-token);

cp "$SCRIPTPATH"/edge.template.json "$SCRIPTPATH"/edge.json
sed -i.bak "s/@ENV_NAME@/$APIGEE_X_ENV/g" "$SCRIPTPATH"/edge.json && rm "$SCRIPTPATH"/edge.json.bak
sed -i.bak "s|@CERT_PATH@|$TEMP_DIR/badssl.com-client.p12|g" "$SCRIPTPATH"/edge.json && rm "$SCRIPTPATH"/edge.json.bak

sackmesser deploy \
--googleapi \
--description "mTLS badssl demo" \
-d "$SCRIPTPATH" \
-n mtls-demo \
-b "$TEST_BASEPATH" \
-t "$APIGEE_TOKEN" \
-o "$APIGEE_X_ORG" \
-e "$APIGEE_X_ENV"

(cd "$SCRIPTPATH" && TEST_HOST=$APIGEE_X_HOSTNAME TEST_BASEPATH=$TEST_BASEPATH npm run test)

# cleanup
rm "$SCRIPTPATH"/edge.json