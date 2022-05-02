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

export PROJECT="<GCP_PROJECT_ID>"
export APIGEE_HOST="<APIGEE_DOMAIN_NAME>"
export APIGEE_ENV="<APIGEE_ENVIRONMENT_NAME>"

# Set gcloud project
gcloud config set project $PROJECT

# Now create a user and assign read rights to BigQuery
gcloud iam service-accounts create bq-api-service \
    --description="Service account for accessing BQ data for APIs" \
    --display-name="BigQuery API Service"

gcloud projects add-iam-policy-binding $PROJECT \
    --member="serviceAccount:bq-api-service@$PROJECT.iam.gserviceaccount.com" \
    --role="roles/bigquery.dataViewer"

gcloud projects add-iam-policy-binding $PROJECT \
    --member="serviceAccount:bq-api-service@$PROJECT.iam.gserviceaccount.com" \
    --role="roles/bigquery.jobUser"
