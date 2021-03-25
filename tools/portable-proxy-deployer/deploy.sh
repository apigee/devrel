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
-d,--directory, path to the apiproxy folder to be deployed
-e,--environment, Apigee environment name
-g,--github, Link to proxy bundle on github
-n,--api, Overrides the default API proxy name
-o,--organization, Apigee organization name
-u,--username, Apigee User Name (Edge only)
-p,--password, Apigee User Password (Edge only)
-m,--mfa, Apigee MFA code (Edge only)
-t,--token, GCP token (X,hybrid only) or OAuth2 token (Edge)
--description, Human friendly proxy description
EOF
}

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    print_usage
    exit 0
fi

if ! command -v xpath &> /dev/null
then
    echo "[FATAL] please install xpath command before continuing"
    exit 1
fi

while [ "$#" -gt 0 ]; do
  case "$1" in
    -b) base_path="$2"; shift 2;;
    -d) directory="$2"; shift 2;;
    -e) environment="$2"; shift 2;;
    -g) url="$2"; shift 2;;
    -m) mfa="$2"; shift 2;;
    -n) api_name="$2"; shift 2;;
    -o) organization="$2"; shift 2;;
    -p) password="$2"; shift 2;;
    -t) token="$2"; shift 2;;
    -u) username="$2"; shift 2;;

    --directory) directory="${1}"; shift 2;;
    --github) url="${1}"; shift 2;;
    --token) token="${1}"; shift 2;;
    --mfa) mfa="${1}"; shift 2;;
    --api) api_name="${1}"; shift 2;;
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

# Make temp 'deploy-me' directory to keep things clean
TEMP_FOLDER="$PWD/deploy-me"
rm -rf "$TEMP_FOLDER" && mkdir -p "$TEMP_FOLDER"
cleanup() {
  echo "[INFO] removing $TEMP_FOLDER"
  rm  -rf "$TEMP_FOLDER"
}
trap cleanup EXIT

SCRIPT_FOLDER=$( (cd "$(dirname "$0")" && pwd ))
cp "$SCRIPT_FOLDER/pom.xml" "$TEMP_FOLDER/"

if [ -n "$url" ]; then
    pattern='https?:\/\/github.com\/([^\/]*)\/([^\/]*)\/tree\/([^\/]*)\/(.*\/apiproxy)'
    [[ "$url" =~ $pattern ]]
    git_org="${BASH_REMATCH[1]}"
    git_repo="${BASH_REMATCH[2]}"
    git_branch="${BASH_REMATCH[3]}"
    git_path="${BASH_REMATCH[4]}"

    git clone "https://github.com/${git_org}/${git_repo}.git" "$TEMP_FOLDER/$git_repo"
    (cd "$TEMP_FOLDER/$git_repo" && git checkout "$git_branch")
    cp -r "$TEMP_FOLDER/$git_repo/$git_path" "$TEMP_FOLDER/"
elif [ -n "$directory" ]; then
    echo "[INFO] using local directory: $directory"
    cp -r "$directory" "$TEMP_FOLDER/apiproxy"
else
    echo "[INFO] using local directory: $PWD/apiproxy"
    cp -r ./apiproxy "$TEMP_FOLDER/apiproxy"
fi

# Determine Proxy name
proxy_name_in_bundle="$(xpath -q -e 'string(//APIProxy/@name)' "$TEMP_FOLDER"/apiproxy/*.xml)"
api_name=${api_name:=$proxy_name_in_bundle}

# (optional) Override base path
if [ -n "$base_path" ]; then
    echo "[INFO] Setting base path: $base_path"
    sed -i.bak "s|<BasePath>.*</BasePath>|<BasePath>$base_path<\/BasePath>|g" "$TEMP_FOLDER"/apiproxy/proxies/*.xml
    rm "$TEMP_FOLDER"/apiproxy/proxies/*.xml.bak
fi

# (optional) Set Proxy Description
if [ -n "$description" ]; then
    echo "[INFO] Setting description: $description"
    sed -i.bak "s|^.*<Description>.*</Description>||g" "$TEMP_FOLDER"/apiproxy/*.xml
    sed -i.bak "s|</APIProxy>|  <Description>$description</Description>\\n</APIProxy>|g" "$TEMP_FOLDER"/apiproxy/*.xml
    rm "$TEMP_FOLDER"/apiproxy/*.xml.bak
fi

if [ "$apiversion" = "google" ]; then
    # install for apigee x/hybrid
    (cd "$TEMP_FOLDER" && mvn install -B -ntp -Pgoogleapi \
        -Dorg="$organization" \
        -Denv="$environment" \
        -Dproxy.name="$api_name" \
        -Dtoken="$token")
elif [ "$apiversion" = "apigee" ]; then
    # install for apigee Edge
    sed -i.bak "s|<artifactId>.*</artifactId><!--used-by-edge-->|<artifactId>$api_name<\/artifactId>|g" "$TEMP_FOLDER"/pom.xml
    rm "$TEMP_FOLDER"/pom.xml.bak

    (cd "$TEMP_FOLDER" && mvn install -B -ntp -Papigeeapi \
        -Dorg="$organization" \
        -Denv="$environment" \
        -Dproxy.name="$api_name" \
        -Dusername="$username" \
        -Dpassword="$password" \
        -Dtoken="$token" \
        -Dmfa="$mfa")
fi
