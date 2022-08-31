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

source ./scripts/validate.sh
source ./scripts/validate-opdk-edge-setup.sh
source ./scripts/validate-new-gen-setup.sh

export ISTIO_TEMPLATE_VER="istio-1.12"
export STANDALONE_TEMPLATE_VER="envoy-1.15"

export APIGEE_ENVOY_ADAPTER_IMG="google/apigee-envoy-adapter:v2.0.5"
export ENVOY_PROXY_IMG="envoyproxy/envoy:v1.21-latest"

usage() {
    echo -e "$*\n usage: $(basename "$0")" \
        "-t <type> -a <action>\n" \
        "example: $(basename "$0") -t istio-apigee-envoy -a install\n" \
        "example: $(basename "$0") -t istio-apigee-envoy -a delete\n" \
        "example: $(basename "$0") -t standalone-apigee-envoy -a install\n" \
        "example: $(basename "$0") -t standalone-apigee-envoy -a delete\n" \
        "Parameters:\n" \
        "-t --type        : Apigee protected Envoy installation type, valid values 'istio-apigee-envoy'. 'standalone-apigee-envoy'\n" \
        "-a --action      : Install or Delete action, valid values 'install', 'delete'\n" \
        "-p --platform    : Standalone install for platform opdk or edge, valid values 'opdk', 'edge'\n"
    exit 1
}

init() {
    export CLUSTER_CTX="gke_${PROJECT_ID}_${CLUSTER_LOCATION}_${CLUSTER_NAME}"
    export ENVOY_AX_SA="apigee-envoy-adapter-sa"
    export CLI_HOME=$ENVOY_HOME/apigee-remote-service-cli
    export REMOTE_SERVICE_HOME=$ENVOY_HOME/apigee-remote-service-envoy
    export ENVOY_CONFIGS_HOME=$CLI_HOME/envoy-configs-and-samples
    export AX_SERVICE_ACCOUNT=$ENVOY_HOME/$ENVOY_AX_SA.json
    export NAMESPACE="apigee"
    if [ "$PLATFORM" == 'edge' ]; then
        export MGMT_HOST="https://api.enterprise.apigee.com"
    fi
    if [[ -z $PROJECT_ID ]] && [[ $INSTALL_TYPE == 'standalone-apigee-envoy' ]]; then
        export PROJECT_ID=$APIGEE_PROJECT_ID;
    fi
}

createDir() {
    mkdir -p "$CLI_HOME"
    mkdir -p "$REMOTE_SERVICE_HOME"
}

PARAMETERS=()

if [[ $# -ne 4 && $# -ne 6 ]]
then
   usage;
   exit 1;
fi  

while [[ $# -gt 0 ]]
do
    param="$1"
    case $param in
        -t|--type)
        export INSTALL_TYPE="$2"
        shift
        shift
        ;;
        -a|--action)
        export ACTION="$2"
        shift
        shift
        ;;
        -p|--platform)
        export PLATFORM="$2"
        shift
        shift
        ;;
        *)
        PARAMETERS+=("$1")
        shift
        ;;
    esac
done
 
if [[ -z $INSTALL_TYPE ]]; then
    usage "installation type is a mandatory field"
fi

if [[ -z $ACTION ]]; then
    usage "action is a mandatory field"
fi

if [ "$PLATFORM" != 'opdk' ] && [ "$PLATFORM" != 'edge' ] && [ "$PIPELINE_TEST" != 'true' ]
then
    gke-gcloud-auth-plugin --version > /dev/null 2>&1
    RESULT=$?
    if [ $RESULT -eq 0 ]; then
        export USE_GKE_GCLOUD_AUTH_PLUGIN=True
    fi
fi

init;

if [ "$PLATFORM" == 'opdk' ] || [ "$PLATFORM" == 'edge' ]
then
    TOKEN=$(echo -n "$APIGEE_USER":"$APIGEE_PASS" | base64 | tr -d \\r)
    export TOKEN;
    export TOKEN_TYPE="Basic"
else
    export TOKEN_TYPE="Bearer"
    export MGMT_HOST="https://apigee.googleapis.com"
fi

#./scripts/validate.sh
validate;

if [ "$PLATFORM" == 'opdk' ] || [ "$PLATFORM" == 'edge' ]
then
    #./scripts/validate-opdk-edge-setup.sh
    validateOpdkEdgeSetup;
else
    #./scripts/validate-new-gen-setup.sh
    validateNewGenSetup;

    # shellcheck disable=SC2153
    export APIGEE_ORG="$APIGEE_X_ORG"
    # shellcheck disable=SC2153
    export APIGEE_ENV="$APIGEE_X_ENV"
fi

if [[ "$INSTALL_TYPE" == 'istio-apigee-envoy' ]] && [[ "$ACTION" == 'install' ]]; then
    createDir;
    echo "Installing istio-apigee-envoy"
    export TEMPLATE=$ISTIO_TEMPLATE_VER
    ./istio-apigee-envoy-install.sh
elif [[ "$INSTALL_TYPE" == 'istio-apigee-envoy' ]] && [[ "$ACTION" == 'delete' ]]; then
    echo "Deleting istio-apigee-envoy"
    ./scripts/delete-apigee-envoy-setup.sh
elif [[ "$INSTALL_TYPE" == 'standalone-apigee-envoy' ]] && [[ "$ACTION" == 'install' ]]; then
    createDir;
    echo "Installing standalone-apigee-envoy"
    export TEMPLATE=$STANDALONE_TEMPLATE_VER
    ./standalone-apigee-envoy-install.sh
elif [[ "$INSTALL_TYPE" == 'standalone-apigee-envoy' ]] && [[ "$ACTION" == 'delete' ]]; then
    echo "Deleting standalone-apigee-envoy"
    ./scripts/delete-apigee-envoy-setup.sh
else
    usage;
    exit 1; 
fi
