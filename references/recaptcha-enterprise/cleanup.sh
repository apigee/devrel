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

PROJECT_ID=$(gcloud config get-value project)

# Get an Apigee token
APIGEE_TOKEN=$(gcloud auth print-access-token);

# delete developer and related artifacts (client apps)
echo "[INFO] Deleting recaptcha enterprise developer and apps"
sackmesser clean --googleapi -t "$APIGEE_TOKEN"  developer "janedoe@example.com" --quiet

# delete api product
echo "[INFO] Deleting recaptcha enterprise api product"
sackmesser clean --googleapi -t "$APIGEE_TOKEN" product RecaptchaEnterprise --quiet

# delete the API proxy proxy and sharedflow from Apigee X or hybrid
echo "[INFO] Deleting recaptcha enterprise api proxy and shared flow from Apigee (X/hybrid)"
sackmesser clean --googleapi -t "$APIGEE_TOKEN" proxy recaptcha-data-proxy-v1 --quiet
sackmesser clean --googleapi -t "$APIGEE_TOKEN" proxy recaptcha-deliver-token-v1 --quiet
sackmesser clean --googleapi -t "$APIGEE_TOKEN" sharedflow sf-recaptcha-enterprise-v1 --quiet

# Cleanup  GCP Assets
gcloud iam service-accounts delete apigee-recaptcha-sa@"$APIGEE_X_ORG".iam.gserviceaccount.com --project "$PROJECT_ID" -q
