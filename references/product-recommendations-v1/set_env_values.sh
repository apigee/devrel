#! /bin/bash
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

# Example script to set environmenet variables.

# Change to your values
export PROJECT_ID=your_org_name
export ORG=$PROJECT_ID
export ENV=your_env
export ENVGROUP_HOSTNAME=your_api_domain_name
export SPANNER_REGION=regional-us-east1
export CUSTOMER_USERID="6929470170340317899-1"

# No need to change these
export SA=datareader@$PROJECT_ID.iam.gserviceaccount.com
export SPANNER_INSTANCE=product-catalog
export SPANNER_DATABASE=product-catalog-v1
APIKEY=$(curl -s -H "Authorization: Bearer ${TOKEN}" \
    https://apigee.googleapis.com/v1/organizations/"$ORG"/developers/demo@any.com/apps/product-recommendations-v1-app-"$ENV" \
    | jq -r .credentials[0].consumerKey)
export APIKEY