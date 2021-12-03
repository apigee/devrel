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

deleteAll() {
    export deleteProxy='all'
    export deleteSharedflow='all'
    export deleteApp='all'
    export deleteProduct='all'
    export deleteDeveloper='all'
    export deleteKvm='all'
    export deleteCache='all'
    export deleteTargetServer='all'
    export deleteKeystore='all'
    export deleteReference='all'
    export deleteFlowHook='all'
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    all) deleteAll; shift 1;;
    proxy) export deleteProxy="${2}"; shift 2;;
    sharedflow) export deleteSharedflow="${2}"; shift 2;;
    app) export deleteApp="${2}"; shift 2;;
    product) export deleteProduct="${2}"; shift 2;;
    developer) export deleteDeveloper="${2}"; shift 2;;
    kvm) export deleteKvm="${2}"; shift 2;;
    cache) export deleteCache="${2}"; shift 2;;
    targetserver) export deleteTargetServer="${2}"; shift 2;;
    flowhook) export deleteFlowHook="${2}"; shift 2;;
    keystore) export deleteKeystore="${2}"; shift 2;;
    reference) export deleteReference="${2}"; shift 2;;
    *) logfatal "unknown option: $1" >&2; exit 1;;
  esac
done

loginfo "You are about to delete the following resources in the Apigee Org \"$organization\":"
if [ -n "$deleteProxy" ]; then loginfo "API Proxy: $deleteProxy"; fi
if [ -n "$deleteSharedflow" ]; then loginfo "Shared Flow: $deleteSharedflow"; fi
if [ -n "$deleteApp" ]; then loginfo "App: $deleteApp"; fi
if [ -n "$deleteProduct" ]; then loginfo "API Product: $deleteProduct"; fi
if [ -n "$deleteDeveloper" ]; then loginfo "API Product: $deleteDeveloper"; fi
if [ -n "$deleteKvm" ]; then loginfo "KVM: $deleteKvm"; fi
if [ -n "$deleteCache" ]; then loginfo "Cache: $deleteCache"; fi
if [ -n "$deleteTargetServer" ]; then loginfo "TargetServer: $deleteTargetServer"; fi
if [ -n "$deleteFlowHook" ]; then loginfo "FlowHooks: $deleteFlowHook"; fi
if [ -n "$deleteKeystore" ]; then loginfo "KeyStore: $deleteKeystore"; fi
if [ -n "$deleteReference" ]; then loginfo "Reference: $deleteReference"; fi


if [ ! "$quiet" = "T" ]; then
  read -p "Do you want to continue with deleting the resources above? [Y/n]: " -n 1 -r REPLY; printf "\n"
  REPLY=${REPLY:-Y}

  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    loginfo "Starting clean up"
  else
    exit 1
  fi
fi

mgmtAPIDelete() {
    loginfo "Sackmesser clean $1"
    curl -fsS -X DELETE -H "Authorization: Bearer $token" "https://$baseuri/v1/$1" > /dev/null
}

deleteEnvResource() {
    envResourcePath="$1" # 'all' or 'environments/$ENV_NAME/$RESOURCE_TYPE/$RESOURCE_NAME'
    resourceType="$2"

    if [ "$envResourcePath" = "all" ];then
        for env in $allEnvironments; do
            envResources=$(sackmesser list "organizations/$organization/environments/$env/$resourceType" | jq -r -c '.[]|.')
            for resource in $envResources; do
                mgmtAPIDelete "organizations/$organization/environments/$env/$resourceType/$resource"
            done
        done
    else
        mgmtAPIDelete "organizations/$organization/$envResourcePath"
    fi
}

deleteOrgResource() {
    orgResourcePath="$1" # 'all' or '$RESOURCE_TYPE/$RESOURCE_NAME'
    resourceType="$2"

    if [ "$orgResourcePath" = "all" ];then
        orgResourcePath=$(sackmesser list "organizations/$organization/$resourceType" | jq -r '.[]|.')
    fi

    for resource in $orgResourcePath; do
        mgmtAPIDelete "organizations/$organization/$resourceType/$resource"
    done
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
    deleteOrgResource "$deleteProduct" 'apiproducts'
fi

if [ -n "$deleteDeveloper" ]; then
    deleteOrgResource "$deleteDeveloper" 'developers'
fi

if [ -n "$deleteProxy" ]; then
    if [ "$deleteProxy" = "all" ];then
        deleteProxy=$(sackmesser list "organizations/$organization/apis" | jq -r '.[]|.')
    fi
    for env in $allEnvironments; do
        for proxy in $deleteProxy; do
            sackmesser list "organizations/$organization/environments/$env/deployments" | jq -r -c ".[]? | select(.name==\"$proxy\") | .revision" | while read -r revision; do
                mgmtAPIDelete "organizations/$organization/environments/$env/apis/$proxy/revisions/$revision/deployments"
            done
            mgmtAPIDelete "organizations/$organization/apis/$proxy" || logwarn "Proxy $proxy not deleted. It might not exist"
        done
    done
fi

if [ -n "$deleteFlowHook" ]; then
    deleteEnvResource "$deleteFlowHook" 'flowhooks'
fi

if [ -n "$deleteSharedflow" ]; then
    if [ "$deleteSharedflow" = "all" ];then
        deleteSharedflow=$(sackmesser list "organizations/$organization/sharedflows" | jq -r '.[]|.')
    fi
    for env in $allEnvironments; do
        for sharedflow in $deleteSharedflow; do
            logdebug "Undeploying and deleting $sharedflow in $env"
            sackmesser list "organizations/$organization/environments/$env/deployments?sharedFlows=true" | jq -r -c ".[]? | select(.name==\"$sharedflow\") | .revision" | while read -r revision; do
                logdebug "Undeploying and deleting revision $revision of $sharedflow in $env"
                mgmtAPIDelete "organizations/$organization/environments/$env/sharedflows/$sharedflow/revisions/$revision/deployments"
            done
            mgmtAPIDelete "organizations/$organization/sharedflows/$sharedflow" || logwarn "Sharedflow $sharedflow not deleted. It might not exist"
        done
    done
fi

if [ -n "$deleteKvm" ]; then
    if [ "$deleteKvm" = "all" ];then
        deleteOrgResource 'all' 'keyvaluemaps'
        deleteEnvResource 'all' 'keyvaluemaps'
    else
        mgmtAPIDelete "organizations/$organization/$deleteKvm"
    fi
fi

if [ -n "$deleteCache" ]; then
    deleteEnvResource "$deleteCache" 'caches'
fi

if [ -n "$deleteTargetServer" ]; then
    deleteEnvResource "$deleteTargetServer" 'targetservers'
fi

if [ -n "$deleteKeystore" ]; then
    deleteEnvResource "$deleteKeystore" 'keystores'
fi

if [ -n "$deleteReference" ]; then
    deleteEnvResource "$deleteReference" 'references'
fi