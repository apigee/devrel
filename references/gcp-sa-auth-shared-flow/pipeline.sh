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

PROJECT_ID="$(gcloud config get-value project)"
SA_NAME='no-roles-sa'
SA_EMAIL="$SA_NAME@$PROJECT_ID.iam.gserviceaccount.com"

SCRIPTPATH="$( cd "$(dirname "$0")" || exit >/dev/null 2>&1 ; pwd -P )"
export PATH="$PATH:$SCRIPTPATH/../../tools/apigee-sackmesser/bin"

# create a service account without any roles and download the key
EXISTING_EMAIL=$(gcloud iam service-accounts list --filter="email=$SA_EMAIL" --format="get(email)")
if [ "$EXISTING_EMAIL" != "$SA_EMAIL" ]; then
  gcloud iam service-accounts create "$SA_NAME"
fi
gcloud iam service-accounts keys create "$SCRIPTPATH/$SA_NAME-key.json" \
  --iam-account "$SA_EMAIL"

# Apigee Edge Pipeline
"$SCRIPTPATH"/deploy.sh "$SCRIPTPATH/$SA_NAME-key.json" --apigeeapi
sackmesser deploy --apigeeapi -d "$SCRIPTPATH"/test/token-validation \
  -u "$APIGEE_USER" -p "$APIGEE_PASS" -o "$APIGEE_ORG" -e "$APIGEE_ENV" \
  -n token-validation-v0

curl --fail "https://$APIGEE_ORG-$APIGEE_ENV.apigee.net/token-validation/v0/oauth"
curl --fail "https://$APIGEE_ORG-$APIGEE_ENV.apigee.net/token-validation/v0/jwt"

# Apigee X Pipeline
"$SCRIPTPATH"/deploy.sh "$SCRIPTPATH/$SA_NAME-key.json" --googleapi
APIGEE_TOKEN=$(gcloud auth print-access-token)
sackmesser deploy --googleapi -d "$SCRIPTPATH"/test/token-validation \
  -t "$APIGEE_TOKEN" -o "$APIGEE_X_ORG" -e "$APIGEE_X_ENV" \
  -n token-validation-v0


curl -k --fail "https://$APIGEE_X_HOSTNAME/token-validation/v0/oauth"
curl -k --fail "https://$APIGEE_X_HOSTNAME/token-validation/v0/jwt"

for SA_KEY_NAME in $(gcloud iam service-accounts keys list --iam-account="$SA_EMAIL" --format="get(name)" --filter="keyType=USER_MANAGED")
do
  gcloud iam service-accounts keys delete "$SA_KEY_NAME" --iam-account="$SA_EMAIL" -q
done