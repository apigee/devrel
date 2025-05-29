#! /bin/bash

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

# Usage: ${APIGEE_MIGRATE_EDGE_TO_X_TOOLS_DIR}/clean_apps.sh

gcloud config get project
echo X_ORG="$X_ORG"

echo '*******************************************'
echo WARNING WARNING WARNING
echo This will attempt to remove all developers and their apps from the org, not just the ones that were imported!
echo WARNING WARNING WARNING
echo '*******************************************'

read -r -p "OK to proceed (Y/n)? " i
if [ "$i" != "Y" ]
then
  echo aborted
  exit 1
fi
echo Proceeding...

TOKEN=$(gcloud auth print-access-token)

AUTH="Authorization: Bearer $TOKEN"

for DEV in $(curl -s -H "$AUTH" https://apigee.googleapis.com/v1/organizations/"$X_ORG"/developers | jq -r .developer[].email)
do 
    echo DEV: "$DEV"
    ENC_DEV=encoded_string=$(printf "%s" "$DEV" | jq -sRr @uri)
    curl -X DELETE -H "$AUTH" https://apigee.googleapis.com/v1/organizations/"$X_ORG"/developers/"$ENC_DEV" 
done