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

echo [INFO] Pipeline for product-recommendations-api in project: "$PROJECT_ID"

# Set project for gcloud commands 
gcloud config set project "$PROJECT_ID"

echo "[INFO] Pipeline for product-recommendations-api enable APIs"
gcloud services enable bigquery.googleapis.com 
gcloud services enable spanner.googleapis.com

echo "[INFO] Pipeline for product-recommendations-api - create service accounts"
CURRENT_ACCOUNT=$(gcloud config get-value account)
setup_service_accounts.sh

echo "[INFO] Pipeline for product-recommendations-api - setup bigquery"
setup_bigquery.sh

echo "[INFO] Pipeline for product-recommendations-api - setup spanner"
setup_spanner.sh

echo "[INFO] Pipeline for product-recommendations-api - maven apigee install"
# This performs end-to-end install, configuration and testing API.
mvn -P eval clean install -Dbearer="$(gcloud auth print-access-token)" \
    -DapigeeOrg="$ORG" \
    -DapigeeEnv="$ENV" \
    -DenvGroupHostname="$ENVGROUP_HOSTNAME" \
    -DgcpProjectId="$PROJECT_ID" \
    -DgoogleTokenEmail="$SA" \
    -DcustomerUserId="$CUSTOMER_USERID"

echo "[INFO] Pipeline for product-recommendations-api - get APIKEY"
# Apigee API call to get API key for use in API calls.
APIKEY=$(curl -s -H "Authorization: Bearer $(gcloud auth print-access-token)" \
    https://apigee.googleapis.com/v1/organizations/"$ORG"/developers/demo@any.com/apps/product-recommendations-v1-app-"$ENV" \
    | jq -r .credentials[0].consumerKey)

echo "[INFO] Pipeline for product-recommendations-api - test api"
# API call to show results
curl -s "https://$ENVGROUP_HOSTNAME/v1/recommendations/products" \
-H "x-apikey:$APIKEY" \
-H "x-userid:$CUSTOMER_USERID" \
-H "Cache-Control:no-cache" | jq

echo "[INFO] Pipeline for product-recommendations-api - maven apigee clean"
mvn -P eval process-resources -Dbearer="$(gcloud auth print-access-token)" \
    -DapigeeOrg="$ORG" -DapigeeEnv="$ENV" -Dskip.integration=true \
    apigee-config:apps apigee-config:apiproducts apigee-config:developers -Dapigee.config.options=delete \
    apigee-enterprise:deploy -Dapigee.options=clean

echo "[INFO] Pipeline for product-recommendations-api - cleanup bigquery"
cleanup_bigquery.sh			

echo "[INFO] Pipeline for product-recommendations-api - cleanup spanner"
cleanup_spanner.sh

echo "[INFO] Pipeline for product-recommendations-api - cleanup service accounts"
gcloud config set account "$CURRENT_ACCOUNT"
cleanup_service_accounts.sh



