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

SACKMESSER_ROOT=$( (cd "$(dirname "$0")" && cd .. && pwd ))
source "$SACKMESSER_ROOT/lib/logutils.sh"

print_usage() {
    cat << EOF
usage: sackmesser COMMAND -e ENV -o ORG [--googleapi | --apigeeapi] [-t TOKEN | -u USER -p PASSWORD] [options]

Apigee Sackmesser utility.

Commands:
await
clean
deploy
export
help
list
report

Options:
--googleapi (default), use apigee.googleapis.com (for X, hybrid)
--apigeeapi, use api.enterprise.apigee.com (for Edge)
-b,--base-path, overrides the default base path for the API proxy
-d,--directory, path to the apiproxy or shared flow bundle to be deployed
-e,--environment, Apigee environment name
-g,--github, Link to proxy or shared flow bundle on github
-h,--hostname, publicly reachable hostname for the environment
-L,--baseuri, override default baseuri for the Management API / Apigee API
-m,--mfa, Apigee MFA code (Edge only)
-n,--name, Overrides the default API proxy or shared flow name
-o,--organization, Apigee organization name
-p,--password, Apigee User Password (Edge only)
-t,--token, GCP token (X,hybrid only) or OAuth2 token (Edge)
-u,--username, Apigee User Name (Edge only)
--async, Asynchronous deployment option (X,hybrid only)
--debug, show verbose debug output
--deployment-sa, GCP Service Account to associate with the deployment (X,hybrid only)
--description, Human friendly proxy or shared flow description
--insecure, set this flag if you are using Apigee Private Cloud (OPDK) and http endpoint for Management API
--opdk, set this flag if you are using Apigee Private Cloud (OPDK)
--skip-config, Skip configuration in org export
EOF
}

CMD_TYPE="$1"

if [ -z "$CMD_TYPE" ] || [ "$CMD_TYPE" = "help" ]; then
    print_usage
    exit 0
elif [ -z "$CMD_TYPE" ] || [ ! -f "$SACKMESSER_ROOT"/cmd/"$CMD_TYPE"/"$CMD_TYPE".sh ];then
    logerror "Please provide a valid command"
    exit 1
fi

for dependency in jq xmllint mvn unzip
do
  if ! [ -x "$(command -v $dependency)" ]; then
    >&2 logfatal "Required command is not on your PATH: $dependency."
    >&2 logfatal "Please install it before you continue."
    exit 2
  fi
done

shift 1
posArgs=()

while [ "$#" -gt 0 ]; do
  case "$1" in
    -b) export base_path="$2"; shift 2;;
    -d) export directory="$2"; shift 2;;
    -e) export environment="$2"; shift 2;;
    -g) export url="$2"; shift 2;;
    -h) export hostname="$2"; shift 2;;
    -L) export baseuri="$2"; shift 2;;
    -m) export mfa="$2"; shift 2;;
    -n) export bundle_name="$2"; shift 2;;
    -o) export organization="$2"; shift 2;;
    -p) export password="$2"; shift 2;;
    -t) export token="$2"; shift 2;;
    -u) export username="$2"; shift 2;;

    --async) export deploy_options="async"; shift 1;;
    --base-path) export base_path="${2}"; shift 2;;
    --baseuri) export baseuri="${2}"; shift 2;;
    --debug) export debug="T"; shift 1;;
    --deployment-sa) export deployment_sa="${2}"; shift 2;;
    --description) export description="${2}"; shift 2;;
    --directory) export directory="${2}"; shift 2;;
    --environment) export environment="${2}"; shift 2;;
    --github) export url="${2}"; shift 2;;
    --hostname) export hostname="${2}"; shift 2;;
    --mfa) export mfa="${2}"; shift 2;;
    --name) export bundle_name="${2}"; shift 2;;
    --organization) export organization="${2}"; shift 2;;
    --password) export password="${2}"; shift 2;;
    --quiet) export quiet="T"; shift 1;;
    --token) export token="${2}"; shift 2;;
    --username) export username="${2}"; shift 2;;
    --skip-config) export skip_config="T"; shift 1;;
    --opdk) export opdk="T"; shift 1;;
    --insecure) export insecure="T"; shift 1;;

    --apigeeapi) export apiversion="apigee"; shift 1;;
    --googleapi) export apiversion="google"; shift 1;;

    -*) logfatal "unknown option: $1" >&2; exit 1;;
    *) posArgs+=("$1"); shift 1;;
  esac
done

if [[ -z "$apiversion" ]]; then
    logdebug "using default API version: Google API (apigee.googleapis.com)"
    logdebug "for Apigee Edge (api.enterprise.apigee.com) and Apigee Private Cloud (OPDK), please specify --apigeeapi"
    export apiversion="google"
fi

if [ "$apiversion" = "google" ];then
    export token=${token:-"$(gcloud config config-helper --force-auth-refresh --format json | jq -r '.credential.access_token')"}
    export organization=${organization:-$APIGEE_X_ORG}
    export environment=${environment:-$APIGEE_X_ENV}
    export hostname=${hostname:-$APIGEE_X_HOSTNAME}
    export baseuri=${baseuri:-apigee.googleapis.com}
else
    export password=${password:-$APIGEE_PASS}
    export username=${username:-$APIGEE_USER}
    export organization=${organization:-$APIGEE_ORG}
    export environment=${environment:-$APIGEE_ENV}
    export baseuri=${baseuri:-api.enterprise.apigee.com}
fi

if [[ -z "$token" && (-z "$username"  || -z "$password") ]]; then
    logfatal "required either -t (OAuth2 or GCP access token) or -u and -p (Edge username and password)"
    exit 1
fi

if [[ -z "$token" && "$apiversion" = "apigee" ]]; then
  if [[ "$opdk" = "T" ]]; then
    logdebug "Getting Apigee Basic Auth token for user $username"
    token=$(echo -n "$username:$password" | base64)
    export token
  else
    if [ -z "$mfa" ]; then MFA=""; else MFA="?mfa_token=$mfa"; fi
    logdebug "Getting Apigee OAuth2 token for user $username"
    response=$(curl -fsS -H "Content-Type:application/x-www-form-urlencoded;charset=utf-8" \
      -H "Accept: application/json;charset=utf-8" \
      -H "Authorization: Basic ZWRnZWNsaTplZGdlY2xpc2VjcmV0" \
      -X POST "https://login.apigee.com/oauth/token$MFA" \
      --data-urlencode "username=$username" \
      --data-urlencode "password=$password" \
      --data "grant_type=password")
    token=$(echo "$response" | jq -r '.access_token')
    export token
  fi
fi

logdebug "Apigee OAuth2 (note: Basic Auth for Apigee Private Cloud [OPDK]) access token: ${token:0:8}..."

logdebug "Sackmesser command: $CMD_TYPE"
"$SACKMESSER_ROOT"/cmd/"$CMD_TYPE"/"$CMD_TYPE".sh "${posArgs[@]}"
