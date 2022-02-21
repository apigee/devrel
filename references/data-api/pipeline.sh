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

SCRIPTPATH=$( (cd "$(dirname "$0")" && pwd ))

SA=bq-reader
SA_EMAIL="$SA@$APIGEE_X_ORG.iam.gserviceaccount.com"

EXISTING_EMAIL=$(gcloud iam service-accounts list --filter="email=$SA_EMAIL" --format="get(email)" --project "$APIGEE_X_ORG")

if [ "$EXISTING_EMAIL" != "$SA_EMAIL" ]; then
    gcloud iam service-accounts create "$SA" --project="$APIGEE_X_ORG" --display-name="BQ data reader"
    gcloud projects add-iam-policy-binding "$APIGEE_X_ORG" --member="serviceAccount:$SA_EMAIL" --role="roles/bigquery.dataViewer" --quiet
    gcloud projects add-iam-policy-binding "$APIGEE_X_ORG" --member="serviceAccount:$SA_EMAIL" --role="roles/bigquery.user" --quiet
fi

export BQ_PROJECT_ID="$APIGEE_X_ORG"
export BASE_PATH='/london/bikes/v1'
export DATA_SET='bigquery-public-data.london_bicycles.cycle_hire'
PROXY_NAME="$( tr '/' '-' <<< ${BASE_PATH:1})" && export PROXY_NAME

PROXY_DIR="$SCRIPTPATH/$PROXY_NAME"
rm -rf "$PROXY_DIR"
mkdir "$PROXY_DIR"
cp -r template/* "$PROXY_DIR"


find "$PROXY_DIR"/* -name '*.xml' -print0 |
while IFS= read -r -d '' file; do
    echo "replacing variables in $file"
    envsubst < "$file" > "$file.out"
    mv "$file.out" "$file"
done

mv "$PROXY_DIR/apiproxy/proxy.xml" "$PROXY_DIR/apiproxy/$PROXY_NAME.xml"

APIGEE_TOKEN=$(gcloud auth print-access-token);
sackmesser deploy -o "$APIGEE_X_ORG" -e "$APIGEE_X_ENV" -d "$PROXY_DIR" -t "$APIGEE_TOKEN" --deployment-sa "$SA_EMAIL"

echo "Testing data API ..."
EXPECTED_LENGTH=4
ACTUAL_LENGTH=$(curl --silent --show-error --fail "https://$APIGEE_X_HOSTNAME/london/bikes/v1?limit=$EXPECTED_LENGTH" | jq '(. | length)' )

if ! [ "$EXPECTED_LENGTH" -eq "$ACTUAL_LENGTH" ]; then
    echo "Expected a response with filtered length $EXPECTED_LENGTH but got $ACTUAL_LENGTH results"
    exit 1
fi
