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

PROJECT_ID="$(gcloud config get-value project)"
KVM_NAME='gcp-sa-devrel'
SA_NAME='no-roles-sa'
SA_EMAIL="$SA_NAME@$PROJECT_ID.iam.gserviceaccount.com"

# create a service account without any roles if it doesn't exist
EXISTING_EMAIL=$(gcloud iam service-accounts list --filter="email=$SA_EMAIL" --format="get(email)")
if [ "$EXISTING_EMAIL" != "$SA_EMAIL" ]; then
  gcloud iam service-accounts create "$SA_NAME"
fi

# create a service account key
gcloud iam service-accounts keys create "./$SA_NAME-key.json" \
  --iam-account "$SA_EMAIL"
GCP_SA_KEY=$(jq '. | tostring' < "./$SA_NAME-key.json")
rm "./$SA_NAME-key.json"

#clean up if the KVM and create cache if not already exists
curl -XDELETE -u "$APIGEE_USER:$APIGEE_PASS" "https://api.enterprise.apigee.com/v1/o/$APIGEE_ORG/e/$APIGEE_ENV/keyvaluemaps/$KVM_NAME" || true

curl -XPOST -s -u "$APIGEE_USER:$APIGEE_PASS" "https://api.enterprise.apigee.com/v1/o/$APIGEE_ORG/e/$APIGEE_ENV/caches" \
  -H 'Content-Type: application/json; charset=utf-8' \
  --data-binary @- > /dev/null << EOF
{
  "name":"gcp-tokens",
  "description":"GCP service account tokens",
  "expirySettings": {
    "timeoutInSec": {
      "value":"300"
    }
  }
}
EOF

#don't continue on failure
set -e

curl -XPOST -s -u "$APIGEE_USER:$APIGEE_PASS" "https://api.enterprise.apigee.com/v1/o/$APIGEE_ORG/e/$APIGEE_ENV/keyvaluemaps" \
  -H 'Content-Type: application/json; charset=utf-8' \
  --data-binary @- > /dev/null << EOF
{
  "name": "$KVM_NAME",
  "encrypted": "true",
  "entry": [
    {
      "name": "cantdonothing@iam.gserviceaccount.com",
      "value": $GCP_SA_KEY
    }
  ]
}
EOF

npm run test

# clean up
curl -XDELETE -u "$APIGEE_USER:$APIGEE_PASS" "https://api.enterprise.apigee.com/v1/o/$APIGEE_ORG/e/$APIGEE_ENV/keyvaluemaps/$KVM_NAME"

for SA_KEY_NAME in $(gcloud iam service-accounts keys list --iam-account="$SA_EMAIL" --format="get(name)" --filter="keyType=USER_MANAGED")
do
  gcloud iam service-accounts keys delete "$SA_KEY_NAME" --iam-account="$SA_EMAIL" -q
done