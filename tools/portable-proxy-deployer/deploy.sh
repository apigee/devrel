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
usage: deploy.sh -e ENV -o ORG [-t TOKEN | -u USER -p PASSWORD] [options]

Apigee deployment utility.

Options:
-b,--base-path, overrides the default base path for the API proxy
-d,--directory, path to the apiproxy folder to be deployed
-e,--environment, Apigee environment name
-g,--github, Link to proxy bundle on github
-n,--api, Overrides the default API proxy name
-o,--organization, Apigee organization name
-u,--username, Apigee User Name (Edge only)
-p,--password, Apigee User Password (Edge only)
-m,--mfa, Apigee MFA code (Edge only)
-t,--token, GCP Token (X,hybrid only)
--description, Human friendly proxy description
EOF
}

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    print_usage
    exit 0
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

    -*) echo "[FATAL] unknown option: $1" >&2; exit 1;;
    *) echo "[INFO] additional argument $1"; shift 1;;
  esac
done

if [[ -z "$token" && (-z "$username"  || -z "$password") ]]; then
    echo "[FATAL] required either -t (GCP access token) or -u and -p (Edge username and password)"
    exit 1
fi

# Make temp 'deploy-me' directory to keep things clean
mkdir -p ./deploy-me
SCRIPT_FOLDER=$( (cd "$(dirname "$0")" && pwd ))
cp "$SCRIPT_FOLDER/pom.xml" ./deploy-me/
cd deploy-me

if [ -n "$url" ]; then
    pattern='https?:\/\/github.com\/([^\/]*)\/([^\/]*)\/tree\/([^\/]*)\/(.*\/apiproxy)'
    [[ "$url" =~ $pattern ]]
    git_org="${BASH_REMATCH[1]}"
    git_repo="${BASH_REMATCH[2]}"
    git_branch="${BASH_REMATCH[3]}"
    git_path="${BASH_REMATCH[4]}"

    git clone "https://github.com/${git_org}/${git_repo}.git"
    (cd "$git_repo" && git checkout "$git_branch")
    cp -r "$git_repo/$git_path" .
elif [ -n "$directory" ]; then
    echo "[INFO] using local directory: $directory"
    (cd .. && cp -r "$directory" ./deploy-me/apiproxy)
else
    cp -r ../apiproxy ./apiproxy
fi

# Determine Proxy name
proxy_name_in_bundle="$(xpath -q -e 'string(//APIProxy/@name)' ./apiproxy/*.xml)"
api_name=${api_name:=$proxy_name_in_bundle}

# (optional) Override base path
if [ -n "$base_path" ]; then
    echo "[INFO] Setting base path: $base_path"
    sed -i.bak "s|<BasePath>.*</BasePath>|<BasePath>$base_path<\/BasePath>|g" ./apiproxy/proxies/*.xml
    rm ./apiproxy/proxies/*.xml.bak
fi

# (optional) Set Proxy Description
if [ -n "$description" ]; then
    echo "[INFO] Setting description: $description"
    sed -i.bak "s|^.*<Description>.*</Description>||g" ./apiproxy/*.xml
    sed -i.bak "s|</APIProxy>|  <Description>$description</Description>\\n</APIProxy>|g" ./apiproxy/*.xml
    rm ./apiproxy/*.xml.bak
fi

if [ -n "$token" ]; then
    # install for apigee x/hybrid
    mvn install -B -ntp -Pgoogleapi \
        -Dorg="$organization" \
        -Denv="$environment" \
        -Dproxy.name="$api_name" \
        -Dtoken="$token"
elif [ -n "$username" ] && [ -n "$password" ]; then
    # install for apigee Edge
    sed -i.bak "s|<artifactId>.*</artifactId><!--used-by-edge-->|<artifactId>$api_name<\/artifactId>|g" ./pom.xml
    rm ./pom.xml.bak

    mvn install -B -ntp -Papigeeapi \
        -Dorg="$organization" \
        -Denv="$environment" \
        -Dproxy.name="$api_name" \
        -Dusername="$username" \
        -Dpassword="$password" \
        -Dmfa="$mfa"
fi

#clean up temp 'deploy-me' folder
cd ..
rm -rdf ./deploy-me
