#! /bin/bash
# shellcheck disable=SC2206
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

echo "[INFO] Pipeline for product-recommendations-api - create service account datareader"
# Create Apigee datareater SA
gcloud iam service-accounts create datareader --project="$PROJECT_ID" --display-name="Data reader in Apigee proxy for BQ and Spanner Demo"
gcloud projects add-iam-policy-binding "$PROJECT_ID" --member="serviceAccount:$SA" --role="roles/spanner.databaseUser" --quiet
gcloud projects add-iam-policy-binding "$PROJECT_ID" --member="serviceAccount:$SA" --role="roles/spanner.databaseReader" --quiet
gcloud projects add-iam-policy-binding "$PROJECT_ID" --member="serviceAccount:$SA" --role="roles/bigquery.dataViewer" --quiet
gcloud projects add-iam-policy-binding "$PROJECT_ID" --member="serviceAccount:$SA" --role="roles/bigquery.user" --quiet

# echo "[INFO] Pipeline for product-recommendations-api - create service account demo-installer"
# # Create project demo-installer SA
# gcloud iam service-accounts create demo-installer --project="$PROJECT_ID" --display-name="Installer for Apigee, BQ and Spanner Demo"
# gcloud projects add-iam-policy-binding "$PROJECT_ID" --member="serviceAccount:$SA_INSTALLER" --role="roles/apigee.admin" --quiet
# gcloud projects add-iam-policy-binding "$PROJECT_ID" --member="serviceAccount:$SA_INSTALLER" --role="roles/bigquery.admin" --quiet
# gcloud projects add-iam-policy-binding "$PROJECT_ID" --member="serviceAccount:$SA_INSTALLER" --role="roles/spanner.admin" --quiet
# gcloud projects add-iam-policy-binding "$PROJECT_ID" --member="serviceAccount:$SA_INSTALLER" --role="roles/iam.serviceAccountUser" --quiet
# gcloud iam service-accounts keys create demo-installer-key.json --project="$PROJECT_ID" --iam-account="$SA_INSTALLER"
# gcloud auth activate-service-account "$SA_INSTALLER" --project="$PROJECT_ID" --key-file=demo-installer-key.json
# gcloud config set account "$SA_INSTALLER"
