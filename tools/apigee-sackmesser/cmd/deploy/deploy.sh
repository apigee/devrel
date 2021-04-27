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

print_usage() {
    cat << EOF
usage: deploy.sh -e ENV -o ORG [--googleapi | --apigeeapi] [-t TOKEN | -u USER -p PASSWORD] [options]

Apigee deployment utility.

Options:
--googleapi (default), use apigee.googleapi.com (for X, hybrid)
--apigeeapi, use api.enterprise.apigee.com (for Edge)
-b,--base-path, overrides the default base path for the API proxy
-d,--directory, path to the apiproxy or shared flow bundle to be deployed
-e,--environment, Apigee environment name
-g,--github, Link to proxy or shared flow bundle on github
-n,--name, Overrides the default API proxy or shared flow name
-o,--organization, Apigee organization name
-u,--username, Apigee User Name (Edge only)
-p,--password, Apigee User Password (Edge only)
-m,--mfa, Apigee MFA code (Edge only)
-t,--token, GCP token (X,hybrid only) or OAuth2 token (Edge)
--description, Human friendly proxy or proxy description
EOF
}

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    print_usage
    exit 0
fi

if ! which xmllint > /dev/null; then
    echo "[FATAL] please install xmllint command"
    exit 1
fi

while [ "$#" -gt 0 ]; do
  case "$1" in
    -b) base_path="$2"; shift 2;;
    -d) directory="$2"; shift 2;;
    -e) environment="$2"; shift 2;;
    -g) url="$2"; shift 2;;
    -m) mfa="$2"; shift 2;;
    -n) bundle_name="$2"; shift 2;;
    -o) organization="$2"; shift 2;;
    -p) password="$2"; shift 2;;
    -t) token="$2"; shift 2;;
    -u) username="$2"; shift 2;;

    --directory) directory="${1}"; shift 2;;
    --github) url="${1}"; shift 2;;
    --token) token="${1}"; shift 2;;
    --mfa) mfa="${1}"; shift 2;;
    --name) bundle_name="${1}"; shift 2;;
    --base-path) base-path="${1}"; shift 2;;
    --username) username="${1}"; shift 2;;
    --password) password="${1}"; shift 2;;
    --environment) environment="${1}"; shift 2;;
    --organization) organization="${1}"; shift 2;;
    --description) description="${2}"; shift 2;;

    --apigeeapi) apiversion="apigee"; shift 1;;
    --googleapi) apiversion="google"; shift 1;;

    -*) echo "[FATAL] unknown option: $1" >&2; exit 1;;
    *) echo "[FATAL] unknown positional argument $1"; exit 1;;
  esac
done

if [[ -z "$token" && (-z "$username"  || -z "$password") ]]; then
    echo "[FATAL] required either -t (OAuth2 or GCP access token) or -u and -p (Edge username and password)"
    exit 1
fi

if [[ -z "$apiversion" ]]; then
    echo "[INFO] using default API version: Google API (apigee.googleapi.com)"
    echo "[INFO] for Apigee Edge (api.enterprise.apigee.com) please specify --apigeeapi"
    apiversion="google"
fi

# Make temp 'deploy' directory to keep things clean
temp_folder="$PWD/deploy-$(date +%s)-$RANDOM"
rm -rf "$temp_folder" && mkdir -p "$temp_folder"
cleanup() {
  echo "[INFO] removing $temp_folder"
  rm  -rf "$temp_folder"
}
trap cleanup EXIT

SCRIPT_FOLDER=$( (cd "$(dirname "$0")" && pwd ))

# copy resources to temp directory
if [ -n "$url" ]; then
    pattern='https?:\/\/github.com\/([^\/]*)\/([^\/]*)\/tree\/([^\/]*)\/(.*)'
    [[ "$url" =~ $pattern ]]
    git_org="${BASH_REMATCH[1]}"
    git_repo="${BASH_REMATCH[2]}"
    git_branch="${BASH_REMATCH[3]}"
    git_path="${BASH_REMATCH[4]}"

    git clone "https://github.com/${git_org}/${git_repo}.git" "$temp_folder/$git_repo"
    (cd "$temp_folder/$git_repo" && git checkout "$git_branch")
    cp -r "$temp_folder/$git_repo/$git_path" "$temp_folder/"
else
    source_dir="${directory:-$PWD}"
    echo "[INFO] using local directory: $source_dir"
    [ -d "$source_dir/apiproxy" ] && cp -r "$source_dir/apiproxy" "$temp_folder/apiproxy"
    [ -d "$source_dir/sharedflowbundle" ] && cp -r "$source_dir/sharedflowbundle" "$temp_folder/sharedflowbundle"
    [ -e "$source_dir/edge.json" ] && cp "$source_dir/edge.json" "$temp_folder/"
fi

# Config Deployment
if [ -f "$temp_folder"/edge.json ]; then
    echo "[INFO] Deploying config $temp_folder/edge.json"

    if [ "$apiversion" = "google" ]; then
        jq --arg APIGEE_ENV "$environment" -c '.envConfig[$APIGEE_ENV].keystores[] | .' < edge.json | while read -r line; do
            echo "[INFO] X/hybrid patch: adding keystore: $(echo "$line" | jq -r '.name')"
            curl -X POST "https://apigee.googleapis.com/v1/organizations/$organization/environments/$environment/keystores" \
            -H "Authorization: Bearer $token" \
            -H "Content-Type: application/json" \
            --data "$line"
        done

        jq --arg APIGEE_ENV "$environment" -c '.envConfig[$APIGEE_ENV].aliases[] | .' < edge.json | while read -r line; do
            echo "[INFO] X/hybrid patch: adding key alias: $(echo "$line" | jq -r '.alias')"
            keystorename="$(echo "$line" | jq -r '.keystorename')"
            alias="$(echo "$line" | jq -r '.alias')"
            format="$(echo "$line" | jq -r '.format')"
            curl -X POST "https://apigee.googleapis.com/v1/organizations/$organization/environments/$environment/keystores/$keystorename/aliases?alias=$alias&format=$format" \
            -H "Authorization: Bearer $token" \
            -F password="$(echo "$line" | jq -r '.password')" \
            -F file=@"$(echo "$line" | jq -r '.filePath')"
        done

        jq --arg APIGEE_ENV "$environment" -c '.envConfig[$APIGEE_ENV].targetServers[] | .' < edge.json | while read -r line; do
            echo "[INFO] X/hybrid patch: adding target server: $(echo "$line" | jq -r '.host')"
            curl -X POST "https://apigee.googleapis.com/v1/organizations/$organization/environments/$environment/targetservers" \
            -H "Authorization: Bearer $token" \
            -H "Content-Type: application/json" \
            --data "$line"
        done

        cp "$SCRIPT_FOLDER/pom-config-hybrid.xml" "$temp_folder"
        (cd "$temp_folder" && mvn install -B -ntp -f ./pom-config-hybrid.xml \
            -Dapigee.config.options=update \
            -Dorg="$organization" \
            -Denv="$environment" \
            -Dproxy.name="$bundle_name" \
            -Dtoken="$token")
    else
        cp "$SCRIPT_FOLDER/pom-config-edge.xml" "$temp_folder"
        (cd "$temp_folder" && mvn install -B -ntp -f ./pom-config-edge.xml \
            -Dapigee.config.options=update \
            -Dorg="$organization" \
            -Denv="$environment" \
            -Dproxy.name="$bundle_name" \
            -Dtoken="$token")
    fi
fi

if [ -d "$temp_folder/apiproxy" ] || [ -d "$temp_folder/sharedflowbundle" ]; then
    echo "[INFO] running deployment in $temp_folder"

    if [ -d "$temp_folder/apiproxy" ]; then
        api_type="apiproxy"

        # Determine Proxy name
        name_in_bundle="$(xmllint --xpath 'string(//APIProxy/@name)' "$temp_folder"/apiproxy/*.xml)"
        bundle_name=${bundle_name:=$name_in_bundle}

        # (optional) Override base path
        if [ -n "$base_path" ]; then
            echo "[INFO] Setting base path: $base_path"
            sed -i.bak "s|<BasePath>.*</BasePath>|<BasePath>$base_path<\/BasePath>|g" "$temp_folder"/apiproxy/proxies/*.xml
            rm "$temp_folder"/apiproxy/proxies/*.xml.bak
        fi

        # (optional) Set Proxy Description
        if [ -n "$description" ]; then
            echo "[INFO] Setting description: $description"
            sed -i.bak "s|^.*<Description>.*</Description>||g" "$temp_folder"/apiproxy/*.xml
            sed -i.bak "s|</APIProxy>|  <Description>$description</Description>\\n</APIProxy>|g" "$temp_folder"/apiproxy/*.xml
            rm "$temp_folder"/apiproxy/*.xml.bak
        fi
    fi

    if [ -d "$temp_folder/sharedflowbundle" ]; then
        api_type="sharedflow"

        shared_flow_name_in_bundle="$(xmllint --xpath 'string(//SharedFlowBundle/@name)' "$temp_folder"/sharedflowbundle/*.xml)"
        bundle_name=${bundle_name:=$shared_flow_name_in_bundle}

            # (optional) Set Proxy Description
        if [ -n "$description" ]; then
            echo "[INFO] Setting description: $description"
            sed -i.bak "s|^.*<Description>.*</Description>||g" "$temp_folder"/sharedflowbundle/*.xml
            sed -i.bak "s|</APIProxy>|  <Description>$description</Description>\\n</APIProxy>|g" "$temp_folder"/sharedflowbundle/*.xml
            rm "$temp_folder"/sharedflowbundle/*.xml.bak
        fi
    fi

    echo "[INFO] Deploying $api_type $bundle_name to $apiversion API"

    if [ "$apiversion" = "google" ]; then
        # install for apigee x/hybrid
        cp "$SCRIPT_FOLDER/pom-hybrid.xml" "$temp_folder/pom.xml"
        (cd "$temp_folder" && mvn install -B -ntp \
            -Dapigee.config.options=$CONFIG_OPTION \
            -Dapitype="$api_type" \
            -Dorg="$organization" \
            -Denv="$environment" \
            -Dproxy.name="$bundle_name" \
            -Dtoken="$token")
    elif [ "$apiversion" = "apigee" ]; then
        # install for apigee Edge
        cp "$SCRIPT_FOLDER/pom-edge.xml" "$temp_folder/pom.xml"
        sed -i.bak "s|<artifactId>.*</artifactId><!--used-by-edge-->|<artifactId>$bundle_name<\/artifactId>|g" "$temp_folder"/pom.xml && rm "$temp_folder"/pom.xml.bak
        (cd "$temp_folder" && mvn install -B -ntp \
            -Dapigee.config.options=$CONFIG_OPTION \
            -Dapitype="$api_type" \
            -Dorg="$organization" \
            -Denv="$environment" \
            -Dproxy.name="$bundle_name" \
            -Dusername="$username" \
            -Dpassword="$password" \
            -Dtoken="$token" \
            -Dmfa="$mfa")
    fi
fi

