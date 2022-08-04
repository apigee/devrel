#!/bin/bash

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

if [ "$PLATFORM" != 'edge' ] && [[ -z $APIGEE_X_HOSTNAME ]]; then
    echo "Environment variable APIGEE_X_HOSTNAME is not set, please checkout README.md"
    exit 1
fi

if [[ -z $APIGEE_REMOTE_SRVC_CLI_VERSION ]]; then
    echo "Environment variable APIGEE_REMOTE_SRVC_CLI_VERSION is not set, please checkout https://github.com/apigee/apigee-remote-service-cli/releases/latest"
    exit 1
fi

if [[ -z $APIGEE_REMOTE_SRVC_ENVOY_VERSION ]]; then
    echo "Environment variable APIGEE_REMOTE_SRVC_ENVOY_VERSION is not set, please checkout https://github.com/apigee/apigee-remote-service-envoy/releases/latest"
    exit 1
fi

#Validate the Apigee org and env

curl -i -H "Authorization: ${TOKEN_TYPE} ${TOKEN}" \
"${MGMT_HOST}/v1/organizations/${APIGEE_ORG}" \
2>&1 >/dev/null
RESULT=$?
if [ $RESULT -ne 0 ]; then
  echo "please verify the provided values about Apigee"
  exit 1
fi

#Validate the Apigee virtualhost reachability
#TODO

echo "Validation successful.."