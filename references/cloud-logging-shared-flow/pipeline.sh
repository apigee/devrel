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

set -e

SCRIPTPATH=$( (cd "$(dirname "$0")" && pwd ))

APIGEE_TOKEN=$(gcloud auth print-access-token);

SA_EMAIL="cloud-log-writer@$APIGEE_X_ORG.iam.gserviceaccount.com"

EXISTING_EMAIL=$(gcloud iam service-accounts list --filter="email=$SA_EMAIL" --format="get(email)" --project "$APIGEE_X_ORG")

if [ "$EXISTING_EMAIL" != "$SA_EMAIL" ]; then
  gcloud iam service-accounts create "cloud-log-writer" --project "$APIGEE_X_ORG"
  gcloud projects add-iam-policy-binding "$APIGEE_X_ORG" \
    --member="serviceAccount:$SA_EMAIL" \
    --role="roles/logging.logWriter"
fi

sackmesser deploy --googleapi -d "$SCRIPTPATH" -t "$APIGEE_TOKEN" --deployment-sa "$SA_EMAIL"
sackmesser deploy --googleapi -d "$SCRIPTPATH/test/logging-example" -t "$APIGEE_TOKEN"

TEST_PATH="/logging-example?t=$(date +%s)"
curl "https://${APIGEE_X_HOSTNAME}${TEST_PATH}" -I

i=0
logs_count=0
while [ "$i" -lt 20 ] && [ ! "$logs_count" -gt 0 ]; do
    i=$(( i + 1 ))
    logs_count=$(gcloud logging read "logName=projects/$APIGEE_X_ORG/logs/apigee-runtime AND jsonPayload.requestUri=\"$TEST_PATH\"" --limit 5 --format=json --project "$APIGEE_X_ORG" | jq '. | length')
    echo "(attempt $i) logs found: $logs_count"
    sleep 1
done

if [ "$logs_count" -eq 0 ]; then
    echo "No logs found for test path $TEST_PATH"
    exit 1
fi