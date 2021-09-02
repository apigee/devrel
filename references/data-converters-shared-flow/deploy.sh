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

TOKEN=$(gcloud auth print-access-token)
zip -r sf-data-converters.zip sharedflowbundle
DEPLOYRESULT=$(curl -X POST -H "Content-Type:multipart/form-data" -H "Authorization:Bearer $TOKEN" -F "file=@\"./sf-data-converters.zip\" type=application/zip;filename=\"sf-data-converters.zip\"" 'https://apigee.googleapis.com/v1/organizations/'$APIGEE_X_ORG'/sharedflows?name=SF-Data-Converters&action=import')
echo "$DEPLOYRESULT"
REVISION=$(jq '.revision' <<< "$DEPLOYRESULT")
echo "$REVISION"
NEWREV="${REVISION%\"}"
NEWREV="${NEWREV#\"}"
echo "$NEWREV"
#gcloud apigee apis deploy $NEWREV --environment=$ENV --api=SF-Data-Converters --override
UPDATERESULT=$(curl -X POST -H "Authorization:Bearer $TOKEN" 'https://apigee.googleapis.com/v1/organizations/'$APIGEE_X_ORG'/environments/'$APIGEE_X_ENV'/sharedflows/SF-Data-Converters/revisions/'$NEWREV'/deployments' -d "override=true")
echo "$UPDATERESULT"
