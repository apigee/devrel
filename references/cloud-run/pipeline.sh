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
export PATH="$PATH:$SCRIPTPATH/../../tools/apigee-sackmesser/bin"

PROJECT_ID=$(gcloud config get-value project)
gcloud builds submit --tag "europe-docker.pkg.dev/$PROJECT_ID/devrel/apigee-target:latest" --project "$PROJECT_ID"

gcloud run deploy apigee-target-demo \
         --image="europe-docker.pkg.dev/$PROJECT_ID/devrel/apigee-target:latest" \
         --platform=managed \
         --region=europe-west1 \
         --no-allow-unauthenticated --project "$PROJECT_ID"

SA_EMAIL="apigee-test-cloudrun@$APIGEE_X_ORG.iam.gserviceaccount.com"

if [ -z "$(gcloud iam service-accounts list --filter "$SA_EMAIL" --format="value(email)"  --project "$APIGEE_X_ORG")" ]; then
    gcloud iam service-accounts create apigee-test-cloudrun \
        --description="Apigee Test Cloud Run" --project "$APIGEE_X_ORG"
fi

gcloud run services add-iam-policy-binding apigee-target-demo \
	 --member="serviceAccount:$SA_EMAIL" \
	 --role='roles/run.invoker' \
	 --region=europe-west1 \
	 --platform=managed --project "$PROJECT_ID"

CLOUD_RUN_URL=$(gcloud run services list --filter apigee-target-demo --format="value(status.url)" --limit 1 )

rm -rf "$SCRIPTPATH/cloud-run-v0"
cp -r "$SCRIPTPATH/cloud-run-v0-template" "$SCRIPTPATH/cloud-run-v0"
sed -i.bak "s|CLOUD_RUN_URL|$CLOUD_RUN_URL|g" "$SCRIPTPATH/cloud-run-v0/apiproxy/targets/default.xml"
rm "$SCRIPTPATH/cloud-run-v0/apiproxy/targets/default.xml.bak"

TOKEN="$(gcloud config config-helper --force-auth-refresh --format json | jq -r '.credential.access_token')"
sackmesser deploy -d "$SCRIPTPATH/cloud-run-v0"  -t "$TOKEN" --deployment-sa "$SA_EMAIL"

response=$(curl "https://${APIGEE_X_HOSTNAME}/cloud-run/v0")

if [ "$response" != "Hello from Apigee" ];then
    echo "Got unexpected response: $response"
    exit 1
fi


# Clean up

if [ -z ${DELETE_AFTER_TEST+x} ] && [ "$DELETE_AFTER_TEST" != "false" ];then
    gcloud run services remove-iam-policy-binding apigee-target-demo \
	 --member="serviceAccount:$SA_EMAIL" \
	 --role='roles/run.invoker' \
	 --region=europe-west1 \
	 --platform=managed --project "$PROJECT_ID"

    gcloud run services delete apigee-target-demo --region=europe-west1 \
	 --platform=managed --project "$PROJECT_ID" -q || true
fi

