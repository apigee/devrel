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

partial_uri="$1"
path="${partial_uri%%\?*}"

logdebug "Sackmesser list $partial_uri"

jq_pattern='.'

if [ "$apiversion" = "google" ]; then
    case "$path" in
        */developers) jq_pattern='[.developer[]?|.email]';;
        */apis) jq_pattern='[.proxies[]?|.name]';;
        */sharedflows) jq_pattern='[.sharedFlows[]?|.name]';;
        */apps) jq_pattern='[.app[]?|.appId]';;
        */apiproducts) jq_pattern='[.apiProduct[]?|.name]';;
        */keyvaluemaps/*) echo "{\"name\":\"$(echo "$path" | sed -n -e 's/^.*keyvaluemaps\///p')\", \"encrypted\": \"true\"}" && exit 0;;
        */environments/*/revisions/*/deployments) jq_pattern='.';;
        */environments/*/deployments) jq_pattern='[.deployments[]? | { name: .apiProxy, revision: .revision | tonumber } ]';;
    esac
elif [ "$apiversion" = "apigee" ]; then
    case "$path" in
        */apps/*) jq_pattern='del(.createdBy) | del(.lastModifiedBy)';;
        */developers/*/apps) jq_pattern='.';;
        */developers/*) jq_pattern='del(.createdBy) | del(.lastModifiedBy)';;
        */apiproducts/*) jq_pattern='del(.createdBy) | del(.lastModifiedBy)';;
        */environments/*/revisions/*/deployments) jq_pattern='.';;
        */environments/*/deployments) jq_pattern='[.aPIProxy[]? | { name: .name, revision: .revision[0].name | tonumber } ]';;
    esac
fi


if [ "$opdk" == "T" ]; then
    token=$(echo -n "$username":"$password" | base64)
    if [ "$insecure" == "T" ]; then
        curl -fsS -H "Authorization: Basic $token" "http://$baseuri/v1/$partial_uri" | jq "$jq_pattern"
    else
        curl -fsS -H "Authorization: Basic $token" "https://$baseuri/v1/$partial_uri" | jq "$jq_pattern"
    fi
else 
    curl -fsS -H "Authorization: Bearer $token" "https://$baseuri/v1/$partial_uri" | jq "$jq_pattern"
fi