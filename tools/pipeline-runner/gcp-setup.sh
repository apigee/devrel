#!/bin/sh
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

set -e

# Enable API
gcloud services enable cloudbuild.googleapis.com secretmanager.googleapis.com

# Create Cloud Secret entries for the buid based on environment variables
echo "$APIGEE_PASS" | gcloud secrets create devrel_apigee_pass --data-file=-
echo "$APIGEE_USER" | gcloud secrets create devrel_apigee_user --data-file=-
echo "$GITHUB_TOKEN" | gcloud secrets create devrel_github_token --data-file=-

# Create a dummy service account and store as a Cloud Secret
SA_NAME="no-roles-sa"
PROJECT_ID=$(gcloud config get-value project)
gcloud iam service-accounts create "$SA_NAME" --description "generic SA for DevRel CI"

gcloud iam service-accounts keys create "./$SA_NAME-key.json" \
  --iam-account "$SA_NAME@$PROJECT_ID.iam.gserviceaccount.com"
gcloud secrets create devrel_ci_genericsa --data-file="./$SA_NAME-key.json"
rm "./$SA_NAME-key.json"

# Set cloud build permissions for Cloud Build SA
PROJECT_NUMBER=$(gcloud projects describe "${PROJECT_ID}" --format="value(projectNumber)")
CLOUD_BUILD_SA="$PROJECT_NUMBER@cloudbuild.gserviceaccount.com"
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:$CLOUD_BUILD_SA" \
  --role="roles/secretmanager.secretAccessor"
