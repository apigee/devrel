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

if [ "$2" = "--googleapi" ] || [ "$2" = "--apigeeapi" ]; then
  API="$2"
else
  echo "[FATAL] chose either --googleapi (for Apigee X or hybrid) or --apigeeapi (for Edge)"
  exit 1
fi

if [ "$1" = "all" ]; then
  SF_TO_DEPLOY="$(cd "$SCRIPTPATH" && echo ./*/)"
else
  SF_TO_DEPLOY="$1"
fi

echo "[INFO] deploying $SF_TO_DEPLOY"

cd "$SCRIPTPATH" || exit

for SF in $SF_TO_DEPLOY; do
  if [ "$API" = "--googleapi" ]; then
    ../../tools/apigee-sackmesser/bin/sackmesser deploy -d "$SF" "$API" \
      -t "$APIGEE_TOKEN" -o "$APIGEE_X_ORG" -e "$APIGEE_X_ENV" \
      --description "See Apigee DevRel references/common-shared-flows"
  elif [ "$API" = "--apigeeapi" ]; then
    ../../tools/apigee-sackmesser/bin/sackmesser deploy -d "$SF" "$API" \
      -u "$APIGEE_USER" -p "$APIGEE_PASS" -o "$APIGEE_ORG" -e "$APIGEE_ENV" \
      --description "See Apigee DevRel references/common-shared-flows"
  else
    echo "[FATAL] unknown Apigee API argument: $API"
    exit 1
  fi
done
