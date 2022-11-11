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

SCRIPT_FOLDER=$( (cd "$(dirname "$0")" && pwd ))

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

if [[ ! -f $oas ]]; then
  echo "[ERROR] the provided OAS file does not exist"
  exit 1
fi

# shellcheck disable=SC2016
jq_backends_match='[.paths | to_entries[] | .key as $path |
  .value | to_entries[] | .value["x-google-backend"] as $backend |
  {path: $path, method: .key, target: $backend.address, pathOp: $backend.path_translation, protocol: $backend.protocol}]'

jq_google_allow_match='.["x-google-allow"]'

if [[ $oas == *.yaml || $oas == *.yml ]]; then
  oas_backends=$(yq -o json "$oas" | jq "$jq_backends_match")
  oas_google_allow=$(yq -o json "$oas" | jq -r "$jq_google_allow_match")
elif [[ $oas == *.json ]]; then
  oas_backends=$(jq "$jq_backends_match" "$oas")
  oas_google_allow=$(jq -r "$jq_google_allow_match" "$oas")
else
  echo "[ERROR] the provided OAS $oas has a wrong extension. Allowed extensions: [yaml,yml,json]"
  exit 1
fi

echo "The following Cloud endpoint OAS extensions were found:"

jq <<< "$oas_backends"

proxy_output="./generated/$proxy_name"

if [[ -d "$proxy_output" && $quiet_apply != "true" ]]; then
  read -p "[WARN] proxy with name $proxy_name already exists in generated ouput. Do you want to override it (Y/n)? " -n 1 -r
  echo    # (optional) move to a new line
  if [[ $REPLY =~ ^[Yy]$ ]]
  then
    rm -rdf "$proxy_output"
  else
    echo "[ERROR] aborted"
    exit 1
  fi
fi

proxy_bundle="$proxy_output/apiproxy"
mkdir -p "$proxy_bundle"
proxies_dir="$proxy_bundle/proxies"
mkdir -p "$proxies_dir"
targets_dir="$proxy_bundle/targets"
mkdir -p "$targets_dir"

export BASE_PATH=$base_path
export PROXY_NAME=$proxy_name

envsubst < "$SCRIPT_FOLDER/proxy-template/proxy.xml" > "$proxy_bundle/$proxy_name.xml"

backend_length=$(jq '. | length' <<< "$oas_backends")

CONDITIONAL_FLOWS=""
CONDITIONAL_ROUTE_RULES=""
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

    pathOp=$(jq -r '.['"$i"'].pathOp' <<< "$oas_backends")

    if [[ "$pathOp" == "APPEND_PATH_TO_ADDRESS" ]]; then
      export PATH_OP_POLICY="AM-AppendPath"
    elif [[ "$pathOp" == "CONSTANT_ADDRESS" ]]; then
      export PATH_OP_POLICY="AM-ConstantAddress"
    else
      echo "[WARN] unknown path operation: $pathOp"
    fi

    FLOW=$(envsubst < "$SCRIPT_FOLDER/proxy-template/conditional_flow.xml.partial")
    CONDITIONAL_FLOWS="${CONDITIONAL_FLOWS}${FLOW}"

    # TargetEndpoints
    TARGET_URL=$(jq -r '.['"$i"'].target' <<< "$oas_backends")
    export TARGET_URL
    TARGET_NAME=$(echo "$TARGET_URL" | sed 's/[^0-9a-zA-Z]*//g' | sed -E 's/^https?//g');
    export TARGET_NAME
    if [[ ! -f "$targets_dir/$TARGET_NAME.xml" ]]; then
      envsubst < "$SCRIPT_FOLDER/proxy-template/targets/default.xml" > "$targets_dir/$TARGET_NAME.xml"
    fi
    ROUTE_RULE=$(envsubst < "$SCRIPT_FOLDER/proxy-template/conditional_routerule.xml.partial")
    CONDITIONAL_ROUTE_RULES="${CONDITIONAL_ROUTE_RULES}${ROUTE_RULE}"

  fi
done

cp -r "$SCRIPT_FOLDER/proxy-template/resources" "$proxy_bundle"
cp -r "$SCRIPT_FOLDER/proxy-template/policies" "$proxy_bundle"

export CONDITIONAL_FLOWS
export CONDITIONAL_ROUTE_RULES

if [ "$oas_google_allow" != "all" ]; then
  export NOT_FOUND_STEP='<Step><Name>RF-NotFound</Name></Step>'
else
  echo "[WARN] OAS configured to allow unmatched paths"
fi

envsubst < "$SCRIPT_FOLDER/proxy-template/proxies/default.xml" > "$proxies_dir/default.xml"
