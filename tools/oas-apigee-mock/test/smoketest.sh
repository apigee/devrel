#!/bin/sh
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

# Clean up previously generated files
rm -rf api_bundles

# Generate proxy bundles
node bin/oas-apigee-mock generateApi oas-apigee-mock-orders -s test/oas/orders.yaml
node bin/oas-apigee-mock generateApi oas-apigee-mock-orders-apikey-query -s test/oas/orders-apikey-query.yaml -o
node bin/oas-apigee-mock generateApi oas-apigee-mock-orders-apikey-header -s test/oas/orders-apikey-header.yaml -o


# Deploy proxies
npx apigeetool deployproxy -u "$APIGEE_USER" -p "$APIGEE_PASS" -o "$APIGEE_ORG" -e "$APIGEE_ENV" -n oas-apigee-mock-orders -d api_bundles/oas-apigee-mock-orders -V
npx apigeetool deployproxy -u "$APIGEE_USER" -p "$APIGEE_PASS" -o "$APIGEE_ORG" -e "$APIGEE_ENV" -n oas-apigee-mock-orders-apikey-header -d api_bundles/oas-apigee-mock-orders-apikey-header -V
npx apigeetool deployproxy -u "$APIGEE_USER" -p "$APIGEE_PASS" -o "$APIGEE_ORG" -e "$APIGEE_ENV" -n oas-apigee-mock-orders-apikey-query -d api_bundles/oas-apigee-mock-orders-apikey-query -V

# Create Apigee Developer, App and Product
npx apigeetool createProduct -u "$APIGEE_USER" -p "$APIGEE_PASS" -o "$APIGEE_ORG" --productName "oas-apigee-mock" --proxies "oas-apigee-mock-orders,oas-apigee-mock-orders-apikey-header,oas-apigee-mock-orders-apikey-query" --environments "test"
npx apigeetool createDeveloper -u "$APIGEE_USER" -p "$APIGEE_PASS" -o "$APIGEE_ORG" --email "oas-apigee-mock@example.com" --userName "oas-apigee-mock@example.com" --firstName "oas-apigee-mock" --lastName "Developer"
npx apigeetool createApp -u "$APIGEE_USER" -p "$APIGEE_PASS" -o "$APIGEE_ORG" --email "oas-apigee-mock@example.com" --apiProducts "oas-apigee-mock" --name "oas-apigee-mock-app" > app.json

APIKEY=$(jq '.credentials[0].consumerKey' -r < app.json )
export APIKEY
echo "APIKEY is $APIKEY"

npm test