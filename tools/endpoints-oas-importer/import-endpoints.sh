#!/bin/bash

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

# ensure the script can be run from any folder
SCRIPT_FOLDER=$( (cd "$(dirname "$0")" && pwd ))

# parse the arguments
while [ "$#" -gt 0 ]; do
  case "$1" in
    -b) export base_path="$2"; shift 2;;
    --base-path) export base_path="${2}"; shift 2;;
    -s) export oas="$2"; shift 2;;
    --oas) export oas="${2}"; shift 2;;
    -n) export proxy_name="$2"; shift 2;;
    --name) export proxy_name="${2}"; shift 2;;
    -q) export quiet_apply="true"; shift 1;;
    --quiet) export quiet_apply="true"; shift 1;;
  esac
done

# sanity check on the arguments
if [ -z "$base_path" ]; then
  >&2 echo "[ERROR] proxy base path not specified"
  exit 1
fi

if [ -z "$oas" ]; then
  >&2 echo "[ERROR] path ot OAS file not specified"
  exit 1
fi

if [ -z "$proxy_name" ]; then
  >&2 echo "[ERROR] proxy name not specified"
  exit 1
fi

if [[ ! -f $oas ]]; then
  >&2 echo "[ERROR] the provided OAS file does not exist"
  exit 1
fi

## helper functions

# translate ESP path_operation to Apigee policy
function translate_path_operation() {
  pathOp=$1
  defaultPathOp=$2
  if [[ "$pathOp" == "APPEND_PATH_TO_ADDRESS" ]]; then
    echo "<Step><Name>AM-AppendPath</Name></Step>"
  elif [[ "$pathOp" == "CONSTANT_ADDRESS" ]]; then
    echo "<Step><Name>AM-ConstantAddress</Name></Step>"
  elif [[ "$pathOp" == "null" ]]; then
    echo "<!-- No x-google-backend path_translation specified using default:--> $(translate_path_operation "$defaultPathOp")"
  else
    >&2 echo "[WARN] unknown path operation: $pathOp"
    echo ''
  fi
}

# create a target endpoint
function target_endpoint() {
  backend=$1
  TARGET_URL=$(jq -r '.target' <<< "$backend")
  if [ "$TARGET_URL" == "null" ];then
    echo "<!-- No Target (no root x-google-backend in OAS) -->"
  else
    export TARGET_URL
    if [[ "$(jq -r '.auth' <<< "$backend")" == "true" ]];then
      target_auth="_auth"
      OPTIONAL_AUTHENTICATION=$(envsubst < "$SCRIPT_FOLDER/proxy-template/id_token_auth.xml.partial")
      export OPTIONAL_AUTHENTICATION
    else
      export OPTIONAL_AUTHENTICATION="<!-- Auth Disabled in OAS -->"
    fi
    TARGET_NAME="$(echo "$TARGET_URL" | sed 's/[^0-9a-zA-Z]*//g' | sed -E 's/^https?//g')$target_auth";
    target_path="$targets_dir/$TARGET_NAME.xml"
    export TARGET_NAME
    if [[ ! -f "$target_path" ]]; then
      envsubst < "$SCRIPT_FOLDER/proxy-template/targets/default.xml" > "$target_path"
    fi
    echo "<TargetEndpoint>$TARGET_NAME</TargetEndpoint>"
  fi
}

## Parse the OAS File

# shellcheck disable=SC2016
jq_backend_transform='any($backend.disable_auth!=true) as $auth |
  {path: $path, method: .key, target: $backend.address, pathOp: $backend.path_translation, protocol: $backend.protocol, auth: $auth}'
# shellcheck disable=SC2016
jq_path_backends_match='.paths | to_entries[] | .key as $path | .value | to_entries[] | .value["x-google-backend"] as $backend'
# shellcheck disable=SC2016
jq_root_backend_match='.["x-google-backend"] as $backend | null as $path'
jq_google_allow_match='.["x-google-allow"]'

if [[ $oas == *.yaml || $oas == *.yml ]]; then
  oas_backends=$(yq -o json "$oas" | jq "[$jq_path_backends_match | $jq_backend_transform]")
  oas_root_backend=$(yq -o json "$oas" | jq -r "$jq_root_backend_match | $jq_backend_transform")
  oas_google_allow=$(yq -o json "$oas" | jq -r "$jq_google_allow_match")
elif [[ $oas == *.json ]]; then
  oas_backends=$(jq -r "[$jq_path_backends_match | $jq_backend_transform]" "$oas")
  oas_root_backend=$(jq -r "$jq_root_backend_match | $jq_backend_transform" "$oas")
  oas_google_allow=$(jq -r "$jq_google_allow_match" "$oas")
else
  >&2 echo "[ERROR] the provided OAS $oas has a wrong extension. Allowed extensions: [yaml,yml,json]"
  exit 1
fi

echo "[INFO] The following Cloud endpoint OAS extensions were found:"
jq <<< "$oas_backends"

## create generated output folder for proxy
proxy_output="./generated/$proxy_name"
if [[ -d "$proxy_output" ]]; then
  if [[ $quiet_apply != "true" ]]; then
    read -p "[WARN] proxy with name $proxy_name already exists in generated ouput. Do you want to override it (Y/n)? " -n 1 -r
    echo    # new line
    if [[ $REPLY =~ ^[Yy]$ ]]
    then
      rm -rdf "$proxy_output"
    else
      >&2 echo "[ERROR] aborted"
      exit 1
    fi
  else
    rm -rdf "$proxy_output"
  fi
fi

proxy_bundle="$proxy_output/apiproxy"
mkdir -p "$proxy_bundle"
proxies_dir="$proxy_bundle/proxies"
mkdir -p "$proxies_dir"
targets_dir="$proxy_bundle/targets"
mkdir -p "$targets_dir"
cp -r "$SCRIPT_FOLDER/proxy-template/resources" "$proxy_bundle"
cp -r "$SCRIPT_FOLDER/proxy-template/policies" "$proxy_bundle"

## template proxy manifest
export BASE_PATH=$base_path
export PROXY_NAME=$proxy_name
envsubst < "$SCRIPT_FOLDER/proxy-template/proxy.xml" > "$proxy_bundle/$proxy_name.xml"

## template proxy resources
CONDITIONAL_FLOWS=""
CONDITIONAL_ROUTE_RULES=""

backend_length=$(jq '. | length' <<< "$oas_backends")
for ((i=0; i<backend_length; i++)); do
  path=$(jq -r '.['"$i"'].path' <<< "$oas_backends")
  pathSuffix=${path#"$base_path"}

  if [[ "$pathSuffix" == "$path" ]]; then
    echo "[WARN] $path in OAS didn't match the base path given ($base_path) and is therefore excluded from the proxy"
    continue
  else
    #Conditional Flows
    PATH_CONDITION=$(echo "$pathSuffix" | sed -E 's/[{][^}]*[}]/\*/g')
    export PATH_CONDITION
    VERB_CONDITION=$(jq -r '.['"$i"'].method | ascii_upcase' <<< "$oas_backends")
    export VERB_CONDITION
    FLOW_NAME="$VERB_CONDITION-$(echo "$PATH_CONDITION" | sed 's/*/_/g' | sed 's/[^0-9a-zA-Z_]*//g')"
    export FLOW_NAME




    # If path-specific target was set
    if [[ "$(jq -r '.['"$i"'].target' <<< "$oas_backends")" != "null" ]];then
      PATH_OP="$(translate_path_operation "$(jq -r '.['"$i"'].pathOp' <<< "$oas_backends")" 'CONSTANT_ADDRESS')"
      export PATH_OP
      TARGET_ENDPOINT="$(target_endpoint "$(jq -r '.['"$i"']' <<< "$oas_backends")")"
      export TARGET_ENDPOINT
      ROUTE_RULE=$(envsubst < "$SCRIPT_FOLDER/proxy-template/conditional_routerule.xml.partial")
      CONDITIONAL_ROUTE_RULES="${CONDITIONAL_ROUTE_RULES}${ROUTE_RULE}"
    else
      export PATH_OP="<!-- No path-specific backend defined in OAS -->"
    fi

    FLOW=$(envsubst < "$SCRIPT_FOLDER/proxy-template/conditional_flow.xml.partial")
    CONDITIONAL_FLOWS="${CONDITIONAL_FLOWS}${FLOW}"
  fi
done
export CONDITIONAL_FLOWS
export CONDITIONAL_ROUTE_RULES

# configure 404 response based on x-google-allow
if [ "$oas_google_allow" != "all" ]; then
  export NOT_FOUND_STEP='<Step><Name>RF-NotFound</Name></Step>'
else
  >&2 echo "[WARN] OAS configured to allow unmatched paths"
fi

DEFAULT_TARGET_ENDPOINT="$(target_endpoint "$oas_root_backend")"
export DEFAULT_TARGET_ENDPOINT

DEFAULT_TARGET_PATH_OP="$(translate_path_operation "$(jq -r '.pathOp' <<< "$oas_root_backend")" 'APPEND_PATH_TO_ADDRESS')"
export DEFAULT_TARGET_PATH_OP

envsubst < "$SCRIPT_FOLDER/proxy-template/proxies/default.xml" > "$proxies_dir/default.xml"

>&2 echo "[INFO] your proxy bundle is ready in $proxy_output"
>&2 echo "[INFO] to deploy it to an Apigee org you can run the following command (assuming Apigee DevRel Sackmesser is in the path)"
echo "\$ sackmesser deploy --googleapi -d \"$proxy_output\" -t \"\$APIGEE_TOKEN\" -o \"\$APIGEE_X_ORG\" -e \"\$APIGEE_X_ENV\" -n $PROXY_NAME"
