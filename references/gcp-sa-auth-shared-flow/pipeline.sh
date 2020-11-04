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

# REQUIREMENT:
# Populate a service account key into the environment variable "REF_GCP_SA_SF" e.g. by:
# $ REF_GCP_SA_SF=$(cat /path/to/gcp-sa-key.json | jq '. | tostring')
#
# Hint:
# Make sure that newline characters are properly escaped with `\\n` within
# the content of REF_GCP_SA_SF

# Ensure REF_GCP_SA_SF is set correctly
if [ -z "$REF_GCP_SA_SF" ]; then
    echo "REF_GCP_SA_SF is not set. Please add it to your environment." 1>&2
    exit 1
fi

deleteKVM() {
    curl -XDELETE -u "$APIGEE_USER:$APIGEE_PASS" "https://api.enterprise.apigee.com/v1/o/$APIGEE_ORG/e/$APIGEE_ENV/keyvaluemaps/$1"
}

#clean up if the KVM and create cache if not already exists
deleteKVM 'gcp-sa-devrel'

curl -XPOST -u "$APIGEE_USER:$APIGEE_PASS" "https://api.enterprise.apigee.com/v1/o/$APIGEE_ORG/e/$APIGEE_ENV/caches" \
  -H 'Content-Type: application/json; charset=utf-8' \
  --data-binary @- << EOF
{
  "name":"gcp-tokens",
  "description":"GCP service account tokens",
  "expirySettings": {
    "timeoutInSec": {
      "value":"300"
    }
  }
}
EOF

#don't continue on failure
set -e

curl -XPOST -u "$APIGEE_USER:$APIGEE_PASS" "https://api.enterprise.apigee.com/v1/o/$APIGEE_ORG/e/$APIGEE_ENV/keyvaluemaps" \
  -H 'Content-Type: application/json; charset=utf-8' \
  --data-binary @- << EOF
{
  "name": "gcp-sa-devrel",
  "encrypted": "true",
  "entry": [
    {
      "name": "cantdonothing@iam.gserviceaccount.com",
      "value": $REF_GCP_SA_SF
    }
  ]
}
EOF

npm run test

# clean up
deleteKVM 'gcp-sa-devrel'
