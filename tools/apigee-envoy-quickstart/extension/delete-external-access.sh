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

validate() {
    if [[ -z $PROJECT_ID ]]; then
        echo "Environment variable PROJECT_ID is not set, please checkout README.md"
        exit 1
    fi

    if [[ -z $CLUSTER_NAME ]]; then
        echo "Environment variable CLUSTER_NAME is not set, please checkout README.md"
        exit 1
    fi

    if [[ -z $CLUSTER_LOCATION ]]; then
        echo "Environment variable CLUSTER_LOCATION is not set, please checkout README.md"
        exit 1
    fi

    if [[ -z $ENVOY_HOME ]]; then
        echo "Environment variable ENVOY_HOME is not set, please set this to the location where devrel is downloads, please checkout README.md for more details"
        exit 1
    fi
}

init() {
  export CLUSTER_CTX="gke_${PROJECT_ID}_${CLUSTER_LOCATION}_${CLUSTER_NAME}"
  export ASM_GATEWAYS_NAMESPACE="istio-ingressgateway"
  export USE_GKE_GCLOUD_AUTH_PLUGIN=True
  gcloud container clusters get-credentials "$CLUSTER_NAME" \
     --zone "$CLUSTER_LOCATION" \
     --project "$PROJECT_ID"

}

validate;

init;

rm -Rf "$ENVOY_HOME"/asm
rm "${ENVOY_HOME}"/httpbin-virtual-service.yaml
rm "${ENVOY_HOME}"/httpbin-gateway.yaml
kubectl delete svc istio-ingressgateway -n "$ASM_GATEWAYS_NAMESPACE"
kubectl delete namespace "$ASM_GATEWAYS_NAMESPACE"
