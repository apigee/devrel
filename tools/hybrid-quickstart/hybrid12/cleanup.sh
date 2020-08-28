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

source ./steps.sh

set_config_params

echo "🗑️ Delete Apigee hybrid cluster"

yes | gcloud container clusters delete $CLUSTER_NAME
echo "✅ Apigee hybrid cluster deleted"


echo "🗑️ Clean up Networking"

yes | gcloud compute addresses delete mart-ip --region $REGION
yes | gcloud compute addresses delete api --region $REGION

touch empty-file
gcloud dns record-sets import -z hybridlab \
   --delete-all-existing \
   empty-file
rm empty-file

yes | gcloud dns managed-zones delete hybridlab

echo "✅ Apigee networking cleaned up"

rm -rd apigeectl_*
rm -rd ./hybrid-files
