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


set -e

DEPLOYMENTS=$(aac get-proxy-deployments)

# Undeploy all
for ENV in $(echo "$DEPLOYMENTS" | jq -r '.environment[].name'); do
  PROXIES=$(aac get-proxy-deployments | jq -r ".environment[] | select(.name | contains(\"$ENV\")) | .aPIProxy")
  for PROXY in $(echo "$PROXIES" | jq -r ".[].name"); do
    REVISION=$(echo "$PROXIES" | jq -r ".[] | select(.name | contains(\"$PROXY\")) | .revision[0].name")
    APIGEE_PROXY=$PROXY APIGEE_REV=$REVISION aac undeploy-proxy
  done
done

# Delete all
for PROXY in $(aac list-proxies | jq -r '.[]'); do 
  APIGEE_PROXY=$PROXY aac delete-proxy
done
