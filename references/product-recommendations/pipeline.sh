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

echo Pipeline for product-recommendations-api in project: "$PROJECT_ID"

# Environment variables
echo APIGEE_X_ORG="$APIGEE_X_ORG" APIGEE_X_ENV="$APIGEE_X_ENV" APIGEE_X_HOSTNAME="$APIGEE_X_HOSTNAME"

# Project hosting BigQuery and Spanner, usually same as APIGEE_X_ORG
export PROJECT_ID=$APIGEE_X_ORG
export CUSTOMER_USERID="6929470170340317899-1"
# No need to change these
export SPANNER_INSTANCE=product-catalog
export SPANNER_DATABASE=product-catalog-v1
export SPANNER_REGION=regional-us-east1
export SA=datareader@$PROJECT_ID.iam.gserviceaccount.com
export SA_INSTALLER=demo-installer@$PROJECT_ID.iam.gserviceaccount.com

echo "Pipeline for product-recommendations-api enable APIs"
gcloud services enable bigquery.googleapis.com --project="$PROJECT_ID"
gcloud services enable spanner.googleapis.com --project="$PROJECT_ID"

echo "Pipeline for product-recommendations-api - create service accounts"
CURRENT_ACCOUNT=$(gcloud config get-value account)
setup_service_accounts.sh

echo "Pipeline for product-recommendations-api - setup bigquery"
setup_bigquery.sh

echo "Pipeline for product-recommendations-api - setup spanner"
setup_spanner.sh

echo "Pipeline for product-recommendations-api - maven apigee install"
# This performs end-to-end install, configuration and testing API.
mvn -P eval clean install -Dbearer="$(gcloud auth print-access-token)" \
    -DapigeeOrg="$APIGEE_X_ORG" \
    -DapigeeEnv="$APIGEE_X_ENV" \
    -DenvGroupHostname="$APIGEE_X_HOSTNAME" \
    -DgcpProjectId="$PROJECT_ID" \
    -DgoogleTokenEmail="$SA" \
    -DintegrationTestUserId="$CUSTOMER_USERID"

echo "Pipeline for product-recommendations-api - maven apigee clean"
mvn -P eval process-resources -Dbearer="$(gcloud auth print-access-token)" \
    -DapigeeOrg="$APIGEE_X_ORG" -DapigeeEnv="$APIGEE_X_ENV" -Dskip.integration=true \
    apigee-config:apps apigee-config:apiproducts apigee-config:developers -Dapigee.config.options=delete \
    apigee-enterprise:deploy -Dapigee.options=clean

echo "Pipeline for product-recommendations-api - cleanup bigquery"
cleanup_bigquery.sh			

echo "Pipeline for product-recommendations-api - cleanup spanner"
cleanup_spanner.sh

echo "Pipeline for product-recommendations-api - cleanup service accounts"
gcloud config set account "$CURRENT_ACCOUNT"
cleanup_service_accounts.sh

echo "Pipeline for product-recommendations-api - all done"

