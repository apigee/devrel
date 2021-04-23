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
set -x

mkdir -p ./tmp
curl https://badssl.com/certs/badssl.com-client.p12 -o ./tmp/badssl.com-client.p12

mv edge.json edge_orig.json

# Apigee Edge

TEST_BASEPATH='/badssl/v0'
jq --arg APIGEE_ENV "$APIGEE_ENV" '.envConfig[$APIGEE_ENV]=.envConfig.myenv | del(.envConfig.myenv)' < edge_orig.json > edge.json

../../tools/portable-proxy-deployer/deploy.sh \
--apigeeapi \
--description "deployment from local folder" \
-n mtls-demo \
-b "$TEST_BASEPATH" \
-u "$APIGEE_USER" \
-p "$APIGEE_PASS" \
-o "$APIGEE_ORG" \
-e "$APIGEE_ENV"

TEST_HOST="$APIGEE_ORG-$APIGEE_ENV.apigee.net"
TEST_HOST=$TEST_HOST TEST_BASEPATH=$TEST_BASEPATH npm run test

# Apigee X

APIGEE_TOKEN=$(gcloud auth print-access-token);
jq --arg APIGEE_X_ENV "$APIGEE_X_ENV" '.envConfig[$APIGEE_X_ENV]=.envConfig.myenv | del(.envConfig.myenv)' < edge_orig.json > edge.json

../../tools/portable-proxy-deployer/deploy.sh \
--googleapi \
--description "deployment from local folder" \
-n mtls-demo \
-b "$TEST_BASEPATH" \
-t "$APIGEE_TOKEN" \
-o "$APIGEE_X_ORG" \
-e "$APIGEE_X_ENV"

TEST_HOST=$APIGEE_X_HOST TEST_BASEPATH=$TEST_BASEPATH npm run test

# cleanup
mv edge_orig.json edge.json
