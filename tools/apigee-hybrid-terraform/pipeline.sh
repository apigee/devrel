#!/bin/sh
# Copyright 2025 Google LLC
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

printf "Running hybrid terraform on GKE"

cd apigee-on-gke
//Get GCP Project ID
GCP_PROJECT_ID=$(gcloud config get-value project)

//Set GCP Project ID in terraform.tfvars
sed -i "s/project_id = \"\"/project_id = \"$GCP_PROJECT_ID\"/g" terraform.tfvars
sed -i "s/apigee_org_name = \"\"/apigee_org_name = \"$GCP_PROJECT_ID\"/g" terraform.tfvars

terraform init
terraform plan
terraform apply --auto-approve

#destroy terraform

terraform destroy --auto-approve


