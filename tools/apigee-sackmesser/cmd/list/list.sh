#!/bin/bash
# shellcheck disable=SC2154
# SC2154: Variables are sent in ../../bin/sackmesser

# Copyright 2021 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# <http://www.apache.org/licenses/LICENSE-2.0>
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e

SCRIPT_FOLDER=$( (cd "$(dirname "$0")" && pwd ))
source "$SCRIPT_FOLDER/../../lib/logutils.sh"

api_path="$1"

logdebug "Sackmesser list $api_path"

jq_pattern='.'

if [ "$apiversion" = "google" ]; then
    case "$api_path" in
        */developers) jq_pattern='[.developer[]?|.email]';;
        */apis) jq_pattern='[.proxies[]?|.name]';;
        */sharedflows) jq_pattern='[.sharedFlows[]?|.name]';;
        */apps) jq_pattern='[.app[]?|.appId]';;
        */apiproducts) jq_pattern='[.apiProduct[]?|.name]';;
        */keyvaluemaps/*) echo "{\"name\":\"$(echo "$api_path" | sed -n -e 's/^.*keyvaluemaps\///p')\", \"encrypted\": \"true\"}" && exit 0;;
    esac
elif [ "$apiversion" = "apigee" ]; then
    case "$api_path" in
        */apps/*) jq_pattern='del(.createdBy) | del(.lastModifiedBy)';;
        */developers/*/apps) jq_pattern='.';;
        */developers/*) jq_pattern='del(.createdBy) | del(.lastModifiedBy)';;
        */apiproducts/*) jq_pattern='del(.createdBy) | del(.lastModifiedBy)';;
    esac
fi

curl -fsS -H "Authorization: Bearer $token" "https://$baseuri/v1/$api_path" | jq "$jq_pattern"
