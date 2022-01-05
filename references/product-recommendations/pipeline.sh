#!/bin/sh
# shellcheck disable=SC2181
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

echo Pipeline for product-recommendations in project: "$PROJECT_ID"

# Environment variables
echo APIGEE_X_ORG="$APIGEE_X_ORG" APIGEE_X_ENV="$APIGEE_X_ENV" APIGEE_X_HOSTNAME="$APIGEE_X_HOSTNAME"

# Project hosting BigQuery and Spanner, usually same as APIGEE_X_ORG
export PROJECT_ID="$APIGEE_X_ORG"
export CUSTOMER_USERID="6929470170340317899-1"

# No need to change these
export SPANNER_INSTANCE=product-catalog
export SPANNER_DATABASE=product-catalog-v1
export SPANNER_REGION=regional-us-east1
export SA=datareader@"$PROJECT_ID".iam.gserviceaccount.com

echo "Pipeline for product-recommendations - setup bigquery"
./setup_bigquery.sh

echo "Pipeline for product-recommendations - setup spanner"
./setup_spanner.sh

echo "Pipeline for product-recommendations - maven apigee install"
# This performs end-to-end install, configuration and testing API.
mvn -P eval clean install -Dbearer="$(gcloud auth print-access-token)" \
    -DapigeeOrg="$APIGEE_X_ORG" \
    -DapigeeEnv="$APIGEE_X_ENV" \
    -DenvGroupHostname="$APIGEE_X_HOSTNAME" \
    -DgcpProjectId="$PROJECT_ID" \
    -DgoogleTokenEmail="$SA" \
    -DintegrationTestUserId="$CUSTOMER_USERID"
if [ $? != 0 ]; then
    echo "Pipeline for product-recommendations - maven apigee install failed, cleaning up bigquery and spanner"
    ./cleanup_bigquery.sh
    ./cleanup_spanner.sh
    exit 1
fi

echo "Pipeline for product-recommendations - maven apigee clean"
mvn -P eval process-resources -Dbearer="$(gcloud auth print-access-token)" \
    -DapigeeOrg="$APIGEE_X_ORG" -DapigeeEnv="$APIGEE_X_ENV" -Dskip.integration=true \
    apigee-config:apps apigee-config:apiproducts apigee-config:developers -Dapigee.config.options=delete \
    apigee-enterprise:deploy -Dapigee.options=clean

echo "Pipeline for product-recommendations - cleanup bigquery"
./cleanup_bigquery.sh			

echo "Pipeline for product-recommendations - cleanup spanner"
./cleanup_spanner.sh

echo "Pipeline for product-recommendations - all done"
