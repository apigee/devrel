#!/bin/bash

# Copyright 2020 Google LLC
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

gcloud iam service-accounts create $ENVOY_AX_SA \
--project=$APIGEE_PROJECT_ID

gcloud projects add-iam-policy-binding $APIGEE_PROJECT_ID --member \
"serviceAccount:$ENVOY_AX_SA@$APIGEE_PROJECT_ID.iam.gserviceaccount.com" \--role "roles/apigee.analyticsAgent"

gcloud projects get-iam-policy $APIGEE_PROJECT_ID --flatten="bindings[].members" \
--format='table(bindings.role)' \
--filter="bindings.members:$ENVOY_AX_SA@$APIGEE_PROJECT_ID.iam.gserviceaccount.com" \
| grep "roles/apigee.analyticsAgent"

gcloud iam service-accounts keys create $AX_SERVICE_ACCOUNT \
--project=$APIGEE_PROJECT_ID \
--iam-account=$ENVOY_AX_SA@$APIGEE_PROJECT_ID.iam.gserviceaccount.com

