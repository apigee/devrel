#!/bin/sh

# Copyright 2024 Google LLC
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

JSON_FILE="./test/email-channel.json"
PROJECT_ID=$1

type=$(jq -r '.type' $JSON_FILE)
displayName=$(jq -r '.displayName' $JSON_FILE)
emailAddress=$(jq -r '.labels.email_address' $JSON_FILE)

list_response=$(gcloud beta monitoring channels list --filter="type='$type' AND displayName=\"$displayName\" AND labels.email_address='$emailAddress'" --format=json --verbosity=none --project="$PROJECT_ID"  2>&1)

if [ "$list_response" = "[]" ]; then

    # create if not existing
    create_response=$(gcloud beta monitoring channels create --channel-content-from-file="$JSON_FILE" --project="$PROJECT_ID" 2>&1)
    exit_status=$?
    
    if [ "$exit_status" -eq 0 ]; then
        channel_id=$(echo "$create_response" | grep -oE "projects/$PROJECT_ID/notificationChannels/[0-9]+" | awk -F'/' '{print $4}')
        echo "$channel_id"
    else
        echo
    fi
else
    comma_separated=$(echo "$list_response" | jq -r '.[].name' | awk -F'/' '{print $4}' | paste -sd "," -)
    echo "$comma_separated"
fi
