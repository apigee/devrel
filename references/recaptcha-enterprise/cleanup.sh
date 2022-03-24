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

# Check for required variables
if [ -z "$GCP_PROJECT" ]; then
  echo "The required env variable GCP_PROJECT is missing";
  exit 1
fi

# Manage optional variables
GCP_REGION=${GCP_REGION:-europe-west1}

# Get an Apigee token
APIGEE_TOKEN=$(gcloud auth print-access-token);

# delete developer and related artifacts (client apps)
echo "[INFO] Deleting recaptcha enterprise developer and apps"
curl --fail --silent -X DELETE \
    -H "Authorization: Bearer $APIGEE_TOKEN" \
    https://apigee.googleapis.com/v1/organizations/"$APIGEE_X_ORG"/developers/janedoe@example.com

# delete api product
echo "[INFO] Deleting recaptcha enterprise api product"
curl --fail --silent -X DELETE \
    -H "Authorization: Bearer $APIGEE_TOKEN" \
    https://apigee.googleapis.com/v1/organizations/"$APIGEE_X_ORG"/apiproducts/RecaptchaEnterprise

# delete the API proxy proxy and sharedflow from Apigee X or hybrid
echo "[INFO] Deleting recaptcha enterprise api proxy and shared flow from Apigee (X/hybrid)"
APIGEE_TOKEN=$(gcloud auth print-access-token);
sackmesser clean --googleapi -t "$APIGEE_TOKEN" proxy data-proxy-v1
sackmesser clean --googleapi -t "$APIGEE_TOKEN" proxy deliver-token-v1
sackmesser clean --googleapi -t "$APIGEE_TOKEN" sharedflow sf-recaptcha-enterprise-v1

# Cleanup  GCP Assets
gcloud iam service-accounts delete apigee-recaptcha-sa@"$GCP_PROJECT".iam.gserviceaccount.com --project "$GCP_PROJECT" -q
