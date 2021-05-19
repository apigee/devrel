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

if [ "$#" -eq 0 ]; then
    loginfo "Select at least one type to clean up. E.g.: \"clean api my-proxy\""
fi


while [ "$#" -gt 0 ]; do
  case "$1" in
    proxy) export deleteProxy="${2}"; shift 2;;
    sharedflow) export deleteSharedflow="${2}"; shift 2;;
    app) export deleteApp="${2}"; shift 2;;
    product) export deleteProduct="${2}"; shift 2;;
    developer) export deleteDeveloper="${2}"; shift 2;;
    *) logfatal "unknown option: $1" >&2; exit 1;;
  esac
done

mgmtAPIDelete() {
    loginfo "Sackmesser clean $1"
    if [ "$apiversion" = "google" ]; then
        curl -s --fail -X DELETE -H "Authorization: Bearer $token" "https://$baseuri/v1/$1" > /dev/null
    else
        curl -u "$username:$password" -s --fail -X DELETE "https://$baseuri/v1/$1" > /dev/null
    fi
}

allEnvironments=$(sackmesser list "organizations/$organization/environments" | jq -r -c '.[]|.')

if [ -n "$deleteApp" ]; then
    if [ "$deleteApp" = "all" ];then
        deleteApp=$(sackmesser list "organizations/$organization/apps" | jq -r '.[]|.')
    fi

    for app in $deleteApp; do
        appInfo=$(sackmesser list "organizations/$organization/apps/$app")
        developer=$(echo "$appInfo" | jq -r '.developerId')
        appName=$(echo "$appInfo" | jq -r '.name')
        mgmtAPIDelete "organizations/$organization/developers/$developer/apps/$appName"
    done
fi

if [ -n "$deleteProduct" ]; then
    if [ "$deleteProduct" = "all" ];then
        deleteProduct=$(sackmesser list "organizations/$organization/apiproducts" | jq -r '.[]|.')
    fi

    for product in $deleteProduct; do
        mgmtAPIDelete "organizations/$organization/apiproducts/$product"
    done
fi

if [ -n "$deleteDeveloper" ]; then
    if [ "$deleteDeveloper" = "all" ];then
        deleteDeveloper=$(sackmesser list "organizations/$organization/developers" | jq -r '.[]|.')
    fi

    for developer in $deleteDeveloper; do
        mgmtAPIDelete "organizations/$organization/developers/$developer"
    done
fi

if [ -n "$deleteProxy" ]; then
    if [ "$deleteProxy" = "all" ];then
        deleteProxy=$(sackmesser list "organizations/$organization/apis" | jq -r '.[]|.')
    fi
    for env in $allEnvironments; do
        deployments=$(sackmesser list "organizations/$organization/environments/$env/deployments")
        for proxy in $deleteProxy; do
            if [ "$apiversion" = "google" ]; then
                revisionJqPattern=".deployments[] | select(.apiProxy==(\"$proxy\")) | .revision"
            else
                revisionJqPattern=".aPIProxy[] | select(.apiProxy==(\"$proxy\")) | .revision[] | .name"
            fi
            echo "$deployments" | jq -r -c "$revisionJqPattern" | while read -r revision; do
                mgmtAPIDelete "organizations/$organization/environments/$env/apis/$proxy/revisions/$revision/deployments"
            done
            mgmtAPIDelete "organizations/$organization/apis/$proxy" || logwarn "Proxy $proxy not deleted. It might not exist"
        done
    done
fi

if [ -n "$deleteSharedflow" ]; then
    if [ "$deleteSharedflow" = "all" ];then
        deleteSharedflow=$(sackmesser list "organizations/$organization/sharedflows" | jq -r '.[]|.')
    fi
    for env in $allEnvironments; do
        deployments=$(sackmesser list "organizations/$organization/environments/$env/deployments?sharedFlows=true")
        for sharedflow in $deleteSharedflow; do
            if [ "$apiversion" = "google" ]; then
                revisionJqPattern=".deployments[] | select(.apiProxy==(\"$sharedflow\")) | .revision"
            else
                revisionJqPattern=".aPIProxy[] | select(.name==(\"$sharedflow\")) | .revision[] | .name"
            fi
            echo "$deployments" | jq -r -c --arg API_PROXY "$sharedflow" "$revisionJqPattern" | while read -r revision; do
                mgmtAPIDelete "organizations/$organization/environments/$env/sharedflows/$sharedflow/revisions/$revision/deployments"
            done
            mgmtAPIDelete "organizations/$organization/sharedflows/$sharedflow" || logwarn "Sharedflow $sharedflow not deleted. It might not exist"
        done
    done
fi

