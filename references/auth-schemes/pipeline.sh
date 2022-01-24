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

developerEmail="alien@far-away.space"
appName="AuthApp"
productName="APIAuthExamples"

rm -f "$SCRIPTPATH"/edge.json
cat <<EOF >> "$SCRIPTPATH/edge.json"
{
    "version": "1.0",
    "envConfig": {
        "$APIGEE_X_ENV": {
            "targetServers": [],
            "virtualHosts": [],
            "caches": [],
            "kvms": []
        }
    },
    "orgConfig": {
        "apiProducts": [
            {
                "name": "$productName",
                "approvalType": "auto",
                "attributes": [
                    {
                        "name": "access",
                        "value": "public"
                    }
                ],
                "description": "Used by apigee/devrel/references/auth-schemes",
                "displayName": "API Auth Examples",
                "environments": [
                    "$APIGEE_X_ENV"
                ],
                "operationGroup": {
                    "operationConfigs": [
                        {
                            "apiSource": "auth-schemes-v0",
                            "operations": [
                            {
                                "resource": "/**",
                                "methods": [
                                    "GET"
                                ]
                            }
                            ],
                            "quota": {}
                        }
                    ],
                    "operationConfigType": "proxy"
                }
            }
        ],
        "developers": [
            {
                "email": "$developerEmail",
                "firstName": "Ally",
                "lastName": "Alien",
                "userName": "allythealien",
                "attributes": []
            }
        ],
        "developerApps": {
            "$developerEmail": [
                {
                    "name": "$appName",
                    "attributes": [],
                    "apiProducts": [
                        "$productName"
                    ],
                    "callbackUrl": "",
                    "scopes": []
                }
            ]
        }
    }
}
EOF

export PATH="$PATH:$SCRIPTPATH/../../tools/apigee-sackmesser/bin"

# deploy Apigee artifacts: proxy, developer, app, product
sackmesser deploy --googleapi -o "$APIGEE_X_ORG" -e "$APIGEE_X_ENV" -t "$APIGEE_X_TOKEN" -h "$APIGEE_X_HOSTNAME" -d "$SCRIPTPATH"

# fetch newly created app
appId=$(sackmesser list --googleapi -t "$APIGEE_X_TOKEN" "organizations/$APIGEE_X_ORG/developers/$developerEmail/apps/$appName" | jq -r '.appId')
appJson=$(sackmesser list --googleapi -t "$APIGEE_X_TOKEN" "organizations/$APIGEE_X_ORG/apps/$appId" | jq '.credentials[0]')

# extract client id and secret from newly created app
export APP_CLIENT_ID="$(echo $appJson | jq -r  '.consumerKey')"
export APP_CLIENT_SECRET="$(echo $appJson | jq -r  '.consumerSecret')"

# var is expected by integration test (apickli)
export PROXY_URL="$APIGEE_X_HOSTNAME/auth-schemes/v0"

# integration tests
npm install
npm run test

# clean up
if [ "$APIGEE_AUTH_SCHEMES_CLEAN_UP" = "true" ]; then
  echo "Cleaning up KMS records..."
  sackmesser clean app "$appId" --googleapi -t "$APIGEE_X_TOKEN" -o "$APIGEE_X_ORG" --quiet
  sackmesser clean developer "$developerEmail" --googleapi -t "$APIGEE_X_TOKEN" -o "$APIGEE_X_ORG" --quiet
  sackmesser clean product "$productName" --googleapi -t "$APIGEE_X_TOKEN" -o "$APIGEE_X_ORG" --quiet
  rm -f "$SCRIPTPATH"/edge.json

  echo "Deleting API proxy..."
  sackmesser clean proxy auth-schemes-v0 --googleapi -t "$APIGEE_X_TOKEN" -o "$APIGEE_X_ORG" --quiet
fi
