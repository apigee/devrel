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

# Usage: ${APIGEE_MIGRATE_EDGE_TO_X_TOOLS_DIR}/create-developers.sh

# TODO: Add check for variables used
echo "$EDGE_ORG"
echo "$APIGEE_MIGRATE_EDGE_TO_X_TOOLS_DIR"
echo "$EDGE_EXPORT_DIR"
echo "$X_IMPORT_DIR"
EDGE_COUNT=500
echo EDGE_COUNT="$EDGE_COUNT"

RESULT='/tmp/developers.json'
TMP_RESULT='/tmp/developers_batches.json'
BATCH='/tmp/developers_batch.json'

# Get the first batch
curl -s -H "$EDGE_AUTH" "https://api.enterprise.apigee.com/v1/organizations/$EDGE_ORG/developers?expand=true&count=$EDGE_COUNT" | jq -r .developer > $RESULT
COUNT=$(jq '. | length' "$RESULT")
echo FIRST_COUNT="$COUNT"

while [ "$COUNT" -ne 0 ]
do
    # Get the last email for the startKey
    START_KEY=$(jq -r '.[-1].email' "$RESULT")
    # echo START_KEY=$START_KEY
    URL_ENCODED_START_KEY=${START_KEY//+/%2B}
    # echo URL_ENCODED_START_KEY=$URL_ENCODED_START_KEY

    # Get all the records after the start key
    curl -s -H "$EDGE_AUTH" "https://api.enterprise.apigee.com/v1/organizations/$EDGE_ORG/developers?expand=true&count=$EDGE_COUNT&startKey=$URL_ENCODED_START_KEY" | jq -r .developer[1:] > $BATCH
    COUNT=$(jq '. | length' $BATCH)
    echo BATCH_COUNT="$COUNT"

    # Slurp the batch into the apps
    if [ "$COUNT" -ne 0 ]; then
        jq -s '. | add' $RESULT $BATCH > "$TMP_RESULT"
        mv "$TMP_RESULT" "$RESULT"
    else
        echo DONE_COUNT="$(jq '. | length' "$RESULT")"
        # Add outer developer property to array, required for apigeecli import
        jq '{ "developer": . }' "$RESULT" > "$TMP_RESULT"
        mv "$TMP_RESULT" "$RESULT"
    fi
done

cp "$RESULT" "$EDGE_EXPORT_DIR"/developers.json

python3 "$APIGEE_MIGRATE_EDGE_TO_X_TOOLS_DIR"/convert-developers-edge-x.py "$EDGE_EXPORT_DIR"/developers.json | jq  > "$X_IMPORT_DIR"/developers.json

