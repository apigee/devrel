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


###############################################################################
# Nightly build script to ensure health of lab instructions 
# Safe to ignore for the purposes of the lab/solution
###############################################################################

set -e

PROJECT_ID="$(gcloud config get-value project)"
sed -i.org "s/eval/$APIGEE_X_ENV/g" edge.json

echo "[INFO] CI and artifact storage using Cloud Build"
SUBSTITUTIONS_X="_APIGEE_ORG=$APIGEE_X_ORG"
SUBSTITUTIONS_X="$SUBSTITUTIONS_X,_APIGEE_ENV=$APIGEE_X_ENV"
SUBSTITUTIONS_X="$SUBSTITUTIONS_X,_APIGEE_RUNTIME_HOST=$APIGEE_X_HOSTNAME"
SUBSTITUTIONS_X="$SUBSTITUTIONS_X,_APIGEE_BUILD_BUCKET=${PROJECT_ID}_cloudbuild"
gcloud builds submit --config=./cloudbuild.yaml \
  --substitutions="$SUBSTITUTIONS_X" || true # ignore failures

echo ""
echo ""
echo "Test: Artifact generated and persisted in GCS"
echo "---------------------------------------------"
gsutil ls -r gs://"${PROJECT_ID}"_cloudbuild/MockTarget/* | grep MockTarget-1.0

echo ""
echo "Test: nonprod API created"
echo "-------------------------"
gcloud apigee apis list --organization="$APIGEE_X_ORG" | grep MockTarget 

echo "Test: nonprod API deployed to env"
echo "---------------------------------"
eval gcloud apigee deployments list --organization="$APIGEE_X_ORG" \
  --api=MockTarget | grep "${APIGEE_X_ENV}"

# In nonprod, GCB doesn't populate COMMIT_SHA for cli builds 
# setting COMMIT_SHA to null so release build picks the built artifact
SUBSTITUTIONS_X="$SUBSTITUTIONS_X,_COMMIT_SHA="
gcloud builds submit --config=./cloudbuild-release.yaml \
  --substitutions="$SUBSTITUTIONS_X" || true # ignore failures

echo ""
echo "Test: release API created"
echo "-------------------------"
gcloud apigee apis list --organization="$APIGEE_X_ORG" | grep MockTarget 

echo "Test: release API deployed to env"
echo "---------------------------------"
gcloud apigee deployments list  --organization="$APIGEE_X_ORG" --api=MockTarget \
  | grep "${APIGEE_X_ENV}"
