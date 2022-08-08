#!/bin/bash

# Copyright 2022 Google LLC
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

if [[ -z $APIGEE_X_ORG ]]; then
    echo "Environment variable APIGEE_X_ORG is not set, please checkout README.md"
    exit 1
fi

if [[ -z $APIGEE_X_ENV ]]; then
    echo "Environment variable APIGEE_X_ENV is not set, please checkout README.md"
    exit 1
fi

if [[ -z $PROJECT_ID ]]; then
    echo "Environment variable PROJECT_ID is not set, please checkout README.md"
    exit 1
fi

if [[ -z $CLUSTER_NAME ]] && [[ $INSTALL_TYPE == 'istio-apigee-envoy' ]]; then
    echo "Environment variable CLUSTER_NAME is not set, please checkout README.md"
    exit 1
fi

if [[ -z $CLUSTER_LOCATION ]] && [[ $INSTALL_TYPE == 'istio-apigee-envoy' ]]; then
    echo "Environment variable CLUSTER_LOCATION is not set, please checkout README.md"
    exit 1
fi

if [[ -z $APIGEE_PROJECT_ID ]]; then
    echo "Environment variable APIGEE_PROJECT_ID is not set, please checkout README.md"
    exit 1
fi

if [[ -z $TOKEN ]]; then
    echo "Environment variable TOKEN is not set, please checkout README.md"
    exit 1
fi

if [[ $INSTALL_TYPE == 'istio-apigee-envoy' ]]; then
  #Validate the kubernetes cluster
  gcloud --project=${PROJECT_ID} container clusters list \
    --filter="name~${CLUSTER_NAME}" >/dev/null
  RESULT=$?
  if [ $RESULT -ne 0 ]; then
    echo "please verify the provided values about GKE cluster"
    exit 1
  fi
fi

echo "Validation istio params successful.."
