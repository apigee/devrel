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

echo "Downloading required libraries from Apigee to configure Envoy adapter"

cd $ENVOY_HOME


wget https://github.com/apigee/apigee-remote-service-cli/releases/download/v${APIGEE_REMOTE_SRVC_CLI_VERSION}/apigee-remote-service-cli_${APIGEE_REMOTE_SRVC_CLI_VERSION}_linux_64-bit.tar.gz \
>/dev/null
RESULT=$?
if [ $RESULT -ne 0 ]; then
  echo "please verify the version number provided for /apigee-remote-service-cli"
  exit 1
fi

wget https://github.com/apigee/apigee-remote-service-envoy/releases/download/v${APIGEE_REMOTE_SRVC_ENVOY_VERSION}/apigee-remote-service-envoy_${APIGEE_REMOTE_SRVC_ENVOY_VERSION}_linux_64-bit.tar.gz \
>/dev/null
RESULT=$?
if [ $RESULT -ne 0 ]; then
  echo "please verify the version number provided for apigee-remote-service-envoy"
  exit 1
fi

tar -xf apigee-remote-service-cli_${APIGEE_REMOTE_SRVC_CLI_VERSION}_linux_64-bit.tar.gz \
-C apigee-remote-service-cli
tar -xf apigee-remote-service-envoy_${APIGEE_REMOTE_SRVC_ENVOY_VERSION}_linux_64-bit.tar.gz \
-C apigee-remote-service-envoy
