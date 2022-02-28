#!/bin/bash

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
APIGEE_TOKEN=$(gcloud auth print-access-token)

DEVELOPER_EMAIL='oauth-admin-pipeline@example.com'
DEVELOPER_APP='oauth-admin-app'
API_PRODUCT='oauth-admin'

function cleanup {
  OAUTH_APP_ID=$(sackmesser list --googleapi -t "$APIGEE_TOKEN" "organizations/$APIGEE_X_ORG/developers/$DEVELOPER_EMAIL/apps/$DEVELOPER_APP" | jq -r '.appId')
  sackmesser clean app "$OAUTH_APP_ID" -t "$APIGEE_TOKEN" -o $APIGEE_X_ORG --quiet || echo "No developer to clean up"
  sackmesser clean developer "$DEVELOPER_EMAIL" -t "$APIGEE_TOKEN" -o $APIGEE_X_ORG --quiet || echo "No developer to clean up"
  sackmesser clean product "$API_PRODUCT" -t "$APIGEE_TOKEN" -o $APIGEE_X_ORG --quiet || echo "No product to clean up"
}
# trap cleanup EXIT

# sackmesser deploy -o $APIGEE_X_ORG -e $APIGEE_X_ENV -t "$APIGEE_TOKEN" -d "$SCRIPTPATH"

# Create a Developer
curl -X POST "https://apigee.googleapis.com/v1/organizations/$APIGEE_X_ORG/developers" \
    -H "Authorization: Bearer $APIGEE_TOKEN" \
    -H "Content-Type: application/json" \
    --data @<(cat <<EOF
{
  "email": "$DEVELOPER_EMAIL",
  "firstName": "oauth",
  "lastName": "admin",
  "userName": "oauthadminpipeline"
}
EOF
)

# Create an API Product for administrating OAuth tokens
curl -X POST "https://apigee.googleapis.com/v1/organizations/$APIGEE_X_ORG/apiproducts" \
    -H "Authorization: Bearer $APIGEE_TOKEN" \
    -H "Content-Type: application/json" \
    --data @<(cat <<EOF
{
  "name": "$API_PRODUCT",
  "operationGroup": {
    "operationConfigs": [
      {
        "apiSource": "oauth-admin-v1",
        "operations": [
          {
            "resource": "/"
          }
        ],
        "quota": {}
      }
    ],
    "operationConfigType": "proxy"
  },
  "environments": [
    "$APIGEE_X_ENV"
  ],
  "attributes": [
    {
      "name": "access",
      "value": "private"
    }
  ],
  "displayName": "[INTERNAL] OAuth Administration Product",
  "approvalType": "manual"
}
EOF
)

# Create an App for the OAuth Admin
curl -X POST "https://apigee.googleapis.com/v1/organizations/$APIGEE_X_ORG/developers/$DEVELOPER_EMAIL/apps" \
    -H "Authorization: Bearer $APIGEE_TOKEN" \
    -H "Content-Type: application/json" \
    --data @<(cat <<EOF
{
  "name": "$DEVELOPER_APP",
  "apiProducts": [
    "$API_PRODUCT"
  ]
}
EOF
)



APP_RESPONSE=$(curl "https://apigee.googleapis.com/v1/organizations/$APIGEE_X_ORG/developers/$DEVELOPER_EMAIL/apps/$DEVELOPER_APP" \
-H "Authorization: Bearer $APIGEE_TOKEN")

export CLIENT_ID=$(echo "$APP_RESPONSE" | jq -r '.credentials[0].consumerKey')
export CLIENT_SECRET=$(echo "$APP_RESPONSE" | jq -r '.credentials[0].consumerSecret')

# Approve the App
curl -X POST "https://apigee.googleapis.com/v1/organizations/$APIGEE_X_ORG/developers/$DEVELOPER_EMAIL/apps/$DEVELOPER_APP/keys/$CLIENT_ID/apiproducts/$API_PRODUCT?action=approve" \
-H "Authorization: Bearer $APIGEE_TOKEN"

echo "Deployment Completed. Running Tests."
