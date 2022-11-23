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
    if [[ "$(jq -r '.backend_auth' <<< "$backend")" == "true" ]];then
      target_auth="_auth"
      OPTIONAL_AUTHENTICATION=$(envsubst < "$SCRIPT_FOLDER/proxy-template/policy-snippets/id_token_auth.xml.partial")
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

function client_authentication() {
  security_setting=$1
  security_definitions=$2

  if [[ "$security_setting" == "null" || "$(jq '. | length' <<< "$security_setting")" -eq "0" ]]; then
    echo "<!-- No security policies defined in OAS -->"
  else
    if [[ "$(jq '. | length' <<< "$security_setting")" -gt "1" ]]; then
      >&2 echo "[WARN] Found more than one security setting. Using the first one to generate the apigee proxy. Manual edits on the proxy bundle might be needed"
    fi
    security_setting_name="$(jq -r '.[0] | to_entries | .[0].key' <<< "$security_setting")"
    security_definition="$(jq -r --arg SEC_NAME "$security_setting_name" '.[$SEC_NAME]' <<< "$security_definitions")"
    if [[ "$security_definition" == "null" ]]; then
      >&2 echo "[ERROR] no matching security definition found for $security_setting_name"
      echo "<!-- No security definition found for $security_setting_name-->"
    else
      SECURITY_POLICY_NAME="OA-VerifyJWT-$security_setting_name"
      export SECURITY_POLICY_NAME
      JWT_ISSUER="$(jq -r '.["x-google-issuer"]' <<< "$security_definition")"
      export JWT_ISSUER
      JWT_JWKS="$(jq -r '.["x-google-jwks_uri"]' <<< "$security_definition")"
      export JWT_JWKS
      JWT_AUDIENCE="$(jq -r '.["x-google-audiences"]' <<< "$security_definition")"
      export JWT_AUDIENCE
      envsubst < "$SCRIPT_FOLDER/proxy-template/policy-templates/OA-VerifyJWT.xml" > "$proxy_bundle/policies/$SECURITY_POLICY_NAME.xml"
      echo "<Step><Name>$SECURITY_POLICY_NAME</Name></Step><Step><Name>AM-RemoveAuthHeader</Name></Step>"
    fi
  fi
}

## Parse the OAS File

# normalizing yaml and json OAS file types
if [[ $oas == *.yaml || $oas == *.yml ]]; then
  oas_json_content=$(yq -o json "$oas")
elif [[ $oas == *.json ]]; then
  oas_json_content=$(cat "$oas")
else
  >&2 echo "[ERROR] the provided OAS $oas has a wrong extension. Allowed extensions: [yaml,yml,json]"
  exit 1
fi

# shellcheck disable=SC2016
jq_backend_transform='any($backend.disable_auth!=true) as $auth |
  {
    path: $path,
    method: .key,
    target: $backend.address,
    pathOp: $backend.path_translation,
    protocol: $backend.protocol,
    backend_auth: $auth,
    client_auth: $security
  }'
# shellcheck disable=SC2016
jq_path_match='.paths | to_entries[] | .key as $path | .value | to_entries[] | .value["x-google-backend"] as $backend | .value["security"] as $security'
# shellcheck disable=SC2016
jq_root_match='.["x-google-backend"] as $backend | null as $path | .["security"] as $security'

oas_path_config=$(jq "[$jq_path_match | $jq_backend_transform]" <<< "$oas_json_content")
oas_root_config=$(jq -r "$jq_root_match | $jq_backend_transform" <<< "$oas_json_content")
oas_google_allow=$(jq -r '.["x-google-allow"]' <<< "$oas_json_content")
oas_security_definitions=$(jq -r '.securityDefinitions' <<< "$oas_json_content")

echo "[INFO] The following OAS extensions were found:"
jq <<< "$oas_path_config"

## create generated output folder for proxy
proxy_output="./generated/$proxy_name"
if [[ -d "$proxy_output" ]]; then
  if [[ $quiet_apply != "true" ]]; then
    read -p "[WARN] proxy with name $proxy_name already exists in generated output. Do you want to override it (Y/n)? " -n 1 -r
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

backend_length=$(jq '. | length' <<< "$oas_path_config")
for ((i=0; i<backend_length; i++)); do
  path=$(jq -r '.['"$i"'].path' <<< "$oas_path_config")
  pathSuffix=${path#"$base_path"}

  if [[ "$pathSuffix" == "$path" ]]; then
    >&2 echo "[WARN] $path in OAS didn't match the base path given ($base_path) and is therefore excluded from the proxy"
    continue
  else
    #Conditional Flows
    PATH_CONDITION=$(echo "$pathSuffix" | sed -E 's/[{][^}]*[}]/\*/g')
    export PATH_CONDITION
    VERB_CONDITION=$(jq -r '.['"$i"'].method | ascii_upcase' <<< "$oas_path_config")
    export VERB_CONDITION
    FLOW_NAME="$VERB_CONDITION-$(echo "$PATH_CONDITION" | sed 's/*/_/g' | sed 's/[^0-9a-zA-Z_]*//g')"
    export FLOW_NAME

    # path-specific target
    if [[ "$(jq -r '.['"$i"'].target' <<< "$oas_path_config")" != "null" ]];then
      PATH_OP="$(translate_path_operation "$(jq -r '.['"$i"'].pathOp' <<< "$oas_path_config")" 'CONSTANT_ADDRESS')"
      export PATH_OP
      TARGET_ENDPOINT="$(target_endpoint "$(jq -r '.['"$i"']' <<< "$oas_path_config")")"
      export TARGET_ENDPOINT
      ROUTE_RULE=$(envsubst < "$SCRIPT_FOLDER/proxy-template/policy-snippets/conditional_routerule.xml.partial")
      CONDITIONAL_ROUTE_RULES="${CONDITIONAL_ROUTE_RULES}${ROUTE_RULE}"
    else
      export PATH_OP="<!-- No path-specific backend defined in OAS -->"
    fi

    # path-specific security
    SECURITY_POLICIES="$(client_authentication "$(jq -r '.['"$i"'].client_auth' <<< "$oas_path_config")" "$oas_security_definitions")"
    export SECURITY_POLICIES

    FLOW=$(envsubst < "$SCRIPT_FOLDER/proxy-template/policy-snippets/conditional_flow.xml.partial")
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

DEFAULT_TARGET_ENDPOINT="$(target_endpoint "$oas_root_config")"
export DEFAULT_TARGET_ENDPOINT

DEFAULT_SECURITY_POLICIES="$(client_authentication "$(jq -r '.client_auth' <<< "$oas_root_config")" "$oas_security_definitions")"
export DEFAULT_SECURITY_POLICIES

DEFAULT_TARGET_PATH_OP="$(translate_path_operation "$(jq -r '.pathOp' <<< "$oas_root_config")" 'APPEND_PATH_TO_ADDRESS')"
export DEFAULT_TARGET_PATH_OP

envsubst < "$SCRIPT_FOLDER/proxy-template/proxies/default.xml" > "$proxies_dir/default.xml"

>&2 echo "[INFO] your proxy bundle is ready in $proxy_output"
>&2 echo "[INFO] to deploy it to an Apigee org you can run the following command (assuming Apigee DevRel Sackmesser is in the path)"
echo "\$ sackmesser deploy --googleapi -d \"$proxy_output\" -t \"\$APIGEE_TOKEN\" -o \"\$APIGEE_X_ORG\" -e \"\$APIGEE_X_ENV\" -n $PROXY_NAME"
