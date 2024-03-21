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

PROJECT_ID=$1
NOTIFICATION_CHANNEL_IDS=$2
IFS=',' 

# Loop through each notification channel ID and delete it
for CHANNEL_ID in $NOTIFICATION_CHANNEL_IDS; do
    gcloud beta monitoring channels delete "$CHANNEL_ID" --project="$PROJECT_ID" --quiet
done
