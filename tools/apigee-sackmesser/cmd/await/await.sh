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

if [ "$#" -ne 2 ]; then
    logerror "Select a resource type and name to await e.g. proxy my-proxy or sharedflow my-sharedflow"
    exit 1
fi

res_type=$1
res_name=$2
res_type_uri='apis'

if [ ! "$res_type" = "proxy" ] && [ ! "$res_type" = "sharedflow" ]; then
    logerror "Unknown resource type \"$res_type\". Select either \"proxy\" or \"sharedflow\"."
    exit 1
fi

if [ "$res_type" = "sharedflow" ];then
    sf_query_param='?sharedFlows=true'
    res_type_uri='sharedflows'
fi

latest_revision=$(sackmesser list "organizations/$organization/environments/$environment/deployments$sf_query_param" | jq -r -c --arg res_name "$res_name" ". | map(select(.name==\"$res_name\") | .revision) | max")

elapsed=0
max_elapsed=75 # max retries

loginfo "Sackmesser await deployment of rev. $latest_revision for $res_type $res_name START (max retries $max_elapsed)"

until [ "$deploy_state" = "READY" ] || [ "$deploy_state" = "deployed" ]; do
    deploy_state=$(sackmesser list "organizations/$organization/environments/$environment/$res_type_uri/$res_name/revisions/$latest_revision/deployments" | jq -r '.state')
    logdebug "Sackmesser await $res_type $res_name: Status: $deploy_state"

    elapsed=$((elapsed+1))

    if [ "$elapsed" -ge "$max_elapsed" ]; then
        logerror "await $ref_type $ref_name has timed out after $elapsed retries"
        exit 1
    fi
    sleep 1
done

loginfo "Sackmesser await deployment of rev. $latest_revision for $res_type $res_name DONE"