#!/bin/sh

# Copyright 2022 Google LLC
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

test_status() {
    url=$1
    expectedstatus=$2
    statuscode=$(curl  -s -o /dev/null -w "%{http_code}" "$url")
    if [ "$statuscode" != "$expectedstatus" ]; then echo "unexpected status code: $statuscode when calling $url" && exit "$statuscode"; fi
}

echo "Endpoints Proxy from YAML with x-google-allow: all"

echo "Generating the proxy from an OAS"
"$SCRIPTPATH/import-endpoints.sh" --oas ./examples/openapi_test.yaml -b /headers -n oas-import-headers -q

echo "Deploying the generated proxy"
APIGEE_TOKEN="$(gcloud config config-helper --force-auth-refresh --format json | jq -r '.credential.access_token')"
sackmesser deploy --googleapi -d "$SCRIPTPATH"/generated/oas-import-headers \
  -t "$APIGEE_TOKEN" -o "$APIGEE_X_ORG" -e "$APIGEE_X_ENV" \
  -n oas-import-headers

echo "Testing if we get the expected responses"
test_status "https://$APIGEE_X_HOSTNAME/headers" "200"
test_status "https://$APIGEE_X_HOSTNAME/headers/my-header-id/bar" "200"
test_status "https://$APIGEE_X_HOSTNAME/headers/foo" "200"

echo "Endpoints Proxy from JSON with default x-google-allow"

echo "Generating the proxy from an OAS"
"$SCRIPTPATH/import-endpoints.sh" --oas ./examples/openapi_test.json -b /ip -n oas-import-ip -q

echo "Deploying the generated proxy"
APIGEE_TOKEN="$(gcloud config config-helper --force-auth-refresh --format json | jq -r '.credential.access_token')"
sackmesser deploy --googleapi -d "$SCRIPTPATH"/generated/oas-import-ip \
  -t "$APIGEE_TOKEN" -o "$APIGEE_X_ORG" -e "$APIGEE_X_ENV" \
  -n oas-import-ip

echo "Testing if we get the expected responses"
test_status "https://$APIGEE_X_HOSTNAME/ip" "200"
test_status "https://$APIGEE_X_HOSTNAME/ip/bar" "200"
test_status "https://$APIGEE_X_HOSTNAME/ip/foo" "404"