#!/bin/sh
# Copyright 2023 Google LLC
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

### script execution starts here...

PROJECT_ID=$(gcloud config get-value project)

# Manage optional variables
export PATH="$PATH:$SCRIPTPATH/../../tools/apigee-sackmesser/bin"

# is Firestore mock enabled (=true) or not (=false)
IS_FIRESTORE_MOCK_ENABLED=${IS_FIRESTORE_MOCK_ENABLED:-true}
export IS_FIRESTORE_MOCK_ENABLED

# set Firestore demo config
envsubst < "$SCRIPTPATH"/templates/AM-SetFirestoreMock.template.xml > "$SCRIPTPATH"/sf-firestore-facade-lookup-v1/sharedflowbundle/policies/AM-SetFirestoreMock.xml

echo "[INFO] Deploying Google Firestore reference to Google API (For X/hybrid)"

TOKEN=$(gcloud auth print-access-token)

SA_EMAIL="apigee-firestore-sa@$APIGEE_X_ORG.iam.gserviceaccount.com"

## Generate Service Account for Apigee shared flow
if [ -z "$(gcloud iam service-accounts list --filter "$SA_EMAIL" --format="value(email)"  --project "$APIGEE_X_ORG")" ]; then
    gcloud iam service-accounts create apigee-firestore-sa \
    --project "$APIGEE_X_ORG"
fi

# If Firestore mock is enabled
if [ "$IS_FIRESTORE_MOCK_ENABLED" = "true" ];then

    # deploy Apigee sharedflows
    sackmesser deploy --googleapi \
        -o "$APIGEE_X_ORG" \
        -e "$APIGEE_X_ENV" \
        -t "$TOKEN" \
        -h "$APIGEE_X_HOSTNAME" \
        -d "$SCRIPTPATH"/sf-firestore-facade-lookup-v1 \
        --debug \
        --deployment-sa "$SA_EMAIL"
    
    sackmesser deploy --googleapi \
        -o "$APIGEE_X_ORG" \
        -e "$APIGEE_X_ENV" \
        -t "$TOKEN" \
        -h "$APIGEE_X_HOSTNAME" \
        -d "$SCRIPTPATH"/sf-firestore-facade-populate-v1 \
        --deployment-sa "$SA_EMAIL"

    # deploy Apigee data proxy
    sackmesser deploy --googleapi \
        -o "$APIGEE_X_ORG" \
        -e "$APIGEE_X_ENV" \
        -t "$TOKEN" \
        -h "$APIGEE_X_HOSTNAME" \
        -d "$SCRIPTPATH"/firestore-data-proxy-v1

    cd "$SCRIPTPATH" && npm i --no-fund && TEST_HOST="$APIGEE_X_HOSTNAME" npm run test

else

    # Create the service account that is used to invoke the Google firebase endpoint
    gcloud projects add-iam-policy-binding "$PROJECT_ID" \
        --member="serviceAccount:$SA_EMAIL" \
        --role="roles/firebase.admin"

     # deploy Apigee sharedflows
    sackmesser deploy --googleapi \
        -o "$APIGEE_X_ORG" \
        -e "$APIGEE_X_ENV" \
        -t "$TOKEN" \
        -h "$APIGEE_X_HOSTNAME" \
        -d "$SCRIPTPATH"/sf-firestore-facade-lookup-v1 \
        --deployment-sa "$SA_EMAIL"
    
    sackmesser deploy --googleapi \
        -o "$APIGEE_X_ORG" \
        -e "$APIGEE_X_ENV" \
        -t "$TOKEN" \
        -h "$APIGEE_X_HOSTNAME" \
        -d "$SCRIPTPATH"/sf-firestore-facade-populate-v1 \
        --deployment-sa "$SA_EMAIL"

    # deploy Apigee data proxy
    sackmesser deploy --googleapi \
        -o "$APIGEE_X_ORG" \
        -e "$APIGEE_X_ENV" \
        -t "$TOKEN" \
        -h "$APIGEE_X_HOSTNAME" \
        -d "$SCRIPTPATH"/firestore-data-proxy-v1

    echo "no tests run for custom Firestore reference configuration."

fi