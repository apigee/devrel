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

###############################
### function: check_env_var ###
###############################
function check_envvars() {
    local varlist=$1

    local varsnotset="F"

    for v in $varlist; do
        if [ -z "${!v}" ]; then
            >&2 echo "Required environment variable $v is not set."
            varsnotset="T" 
        else
	        echo "$v is set!"
        fi
    done

    if [ "$varsnotset" = "T" ]; then
        >&2 echo ""
        >&2 echo "ABEND. Please set up required variables."
        return 1
    fi

}

check_envvars "APIGEE_ORG APIGEE_USER APIGEE_PASS APIGEE_ENV IDP_APIGEE_CLIENT_ID IDP_APIGEE_CLIENT_SECRET"
