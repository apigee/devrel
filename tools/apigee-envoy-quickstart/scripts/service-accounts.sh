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

addAxRole() {
  gcloud projects add-iam-policy-binding "$APIGEE_PROJECT_ID" --member \
    "serviceAccount:$ENVOY_AX_SA@$APIGEE_PROJECT_ID.iam.gserviceaccount.com" \
    --role "roles/apigee.analyticsAgent"
}

getAxRoles() {
  ROLES_ASSIGNED=$(gcloud projects get-iam-policy "$APIGEE_PROJECT_ID" --flatten="bindings[].members" \
    --format='table(bindings.role)' \
    --filter="bindings.members:$ENVOY_AX_SA@$APIGEE_PROJECT_ID.iam.gserviceaccount.com" | \
    grep -c "roles/apigee.analyticsAgent")

  export ROLES_ASSIGNED;
}

FOUND_SA_IN_PROJECT="$(gcloud iam service-accounts list --filter "$ENVOY_AX_SA" \
  --format="value(email)"  --project "$APIGEE_PROJECT_ID" | grep -w "^$ENVOY_AX_SA")"
if [ -z "$FOUND_SA_IN_PROJECT" ]; then
    gcloud iam service-accounts create "$ENVOY_AX_SA" \
    --project="$APIGEE_PROJECT_ID"

    addAxRole;
fi

getAxRoles;
if [[ $ROLES_ASSIGNED == 0 ]] && [[ -z $PIPELINE_TEST ]]; then
  echo "Adding roles..."
  #addAxRole;
fi

getAxRoles;
if [[ $ROLES_ASSIGNED == 0 ]]; then
  echo "Needed roles not assigned, exiting"
  exit 1;
fi

gcloud iam service-accounts keys create "$AX_SERVICE_ACCOUNT" \
--project="$APIGEE_PROJECT_ID" \
--iam-account="$ENVOY_AX_SA"@"$APIGEE_PROJECT_ID".iam.gserviceaccount.com

