#!/bin/sh
# Copyright 2020 Google LLC
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

SCRIPTPATH="$( cd "$(dirname "$0")" || exit >/dev/null 2>&1 ; pwd -P )"
APIGEE_TOKEN=$(gcloud auth print-access-token);

while [ "$#" -gt 0 ]; do
  case "$1" in
    --apigeeapi) apiversion="$1"; shift 1;;
    --googleapi) apiversion="$1"; shift 1;;
    --async) async_flag="--async"; shift 1;;
    *) sf_to_deploy="$1"; shift 1;;
  esac
done

if [ "$apiversion" = "--googleapi" ] || [ "$apiversion" = "--apigeeapi" ]; then
  echo "[INFO] using API version $apiversion"
else
  echo "[FATAL] choose either --googleapi (for Apigee X or hybrid) or --apigeeapi (for Edge)"
  exit 1
fi

if [ "$sf_to_deploy" = "all" ]; then
  sf_to_deploy="$(cd "$SCRIPTPATH" && ls -d "$PWD"/*/)"
fi

echo "[INFO] deploying $sf_to_deploy"

cd "$SCRIPTPATH" || exit
export PATH="$PATH:$SCRIPTPATH/../../tools/apigee-sackmesser/bin"

for SF in $sf_to_deploy; do
  if [ "$apiversion" = "--googleapi" ]; then
    sackmesser deploy -d "$SF" "$apiversion" "$async_flag" \
      -t "$APIGEE_TOKEN" -o "$APIGEE_X_ORG" -e "$APIGEE_X_ENV" \
      --description "See Apigee DevRel references/common-shared-flows"
  elif [ "$apiversion" = "--apigeeapi" ]; then
    sackmesser deploy -d "$SF" "$apiversion" \
      -u "$APIGEE_USER" -p "$APIGEE_PASS" -o "$APIGEE_ORG" -e "$APIGEE_ENV" \
      --description "See Apigee DevRel references/common-shared-flows"
  else
    echo "[FATAL] unknown Apigee API argument: $apiversion"
    exit 1
  fi
done

if [ -n "$async_flag" ] && [ "$apiversion" = "--googleapi" ]; then
  for SF in $sf_to_deploy; do
    sackmesser await sharedflow "$(basename "$SF")" "$apiversion" \
      -t "$APIGEE_TOKEN" -o "$APIGEE_X_ORG" -e "$APIGEE_X_ENV"
  done
fi
