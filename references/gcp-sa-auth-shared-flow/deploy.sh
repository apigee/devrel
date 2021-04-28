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

while [ "$#" -gt 0 ]; do
  case "$1" in
    --apigeeapi) apiversion="$1"; shift 1;;
    --googleapi) apiversion="$1"; shift 1;;
    *) sa_path="$1"; shift 1;;
  esac
done

cp "$SCRIPTPATH"/edge.template.json "$SCRIPTPATH"/edge.json

if [ -f "$sa_path" ];then
    GCP_SA_KEY="$(jq '. | tostring' < "$sa_path" | sed "s|\\\"|\\\\\"|g")"
    sed -i.bak "s|\"@GCP_SA_KEY@\"|$GCP_SA_KEY|g" "$SCRIPTPATH"/edge.json && rm "$SCRIPTPATH"/edge.json.bak
    sed -i.bak 's/\\n/\\\\n/g' "$SCRIPTPATH"/edge.json && rm "$SCRIPTPATH"/edge.json.bak
    sed -i.bak "s|@GCP_SA_KEY_NAME@|apigee@iam.gserviceaccount.com|g" "$SCRIPTPATH"/edge.json && rm "$SCRIPTPATH"/edge.json.bak
else
    echo "[INFO] No SA key provided"
    cp "$SCRIPTPATH"/edge.json "$SCRIPTPATH"/edge.json.bak
    jq 'del(.envConfig["@ENV_NAME@"].kvms)' < "$SCRIPTPATH"/edge.json.bak > "$SCRIPTPATH"/edge.json && rm "$SCRIPTPATH"/edge.json.bak
fi

export PATH="$PATH:$SCRIPTPATH/../../tools/apigee-sackmesser/bin"

if [ "$apiversion" = "--apigeeapi" ]; then
    sed -i.bak "s/@ENV_NAME@/$APIGEE_ENV/g" "$SCRIPTPATH"/edge.json && rm "$SCRIPTPATH"/edge.json.bak
    sackmesser deploy -d "$SCRIPTPATH" "$apiversion" \
        -u "$APIGEE_USER" -p "$APIGEE_PASS" -o "$APIGEE_ORG" -e "$APIGEE_ENV" \
        --description "See Apigee DevRel references/common-shared-flows"
else
    sed -i.bak "s/@ENV_NAME@/$APIGEE_X_ENV/g" "$SCRIPTPATH"/edge.json && rm "$SCRIPTPATH"/edge.json.bak
    APIGEE_TOKEN=$(gcloud auth print-access-token)
    sackmesser deploy -d "$SCRIPTPATH" "$apiversion" \
        -t "$APIGEE_TOKEN" -o "$APIGEE_X_ORG" -e "$APIGEE_X_ENV" -h "$APIGEE_X_HOSTNAME" \
        --description "See Apigee DevRel references/common-shared-flows"
fi

rm "$SCRIPTPATH"/edge.json
