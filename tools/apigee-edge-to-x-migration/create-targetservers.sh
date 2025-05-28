#! /bin/bash

# Copyright 2025 Google LLC
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

# TODO: Add check for variables used
echo $EDGE_ORG
echo $APIGEE_MIGRATE_EDGE_TO_X_TOOLS_DIR
echo $EDGE_EXPORT_DIR
echo $ENVS
echo $X_IMPORT_DIR

for E in $ENVS
do
    export EXPORTED_DIR=$EDGE_EXPORT_DIR/data-env-${E}

    TS=$(ls $EXPORTED_DIR/targetservers)
    # TS="pingstatus-v1 pingstatus-oauth-v1 oauth-v1"

    echo TS $TS TS: ${EXPORTED_DIR}/${TS} TO: ${IMPORT_DIR}/{E}__targetservers.json

    OUTPUT="["
    for T in $TS
    do
        TMP=$(cat $EXPORTED_DIR/targetservers/$T)
        OUTPUT="${OUTPUT}${TMP},"
    done
    OUTPUT="${OUTPUT%?}"
    OUTPUT="${OUTPUT}]"
    echo $OUTPUT | jq > /tmp/${E}__targetservers.json

    python3 $APIGEE_MIGRATE_EDGE_TO_X_TOOLS_DIR/convert-targetservers-edge-x.py /tmp/${E}__targetservers.json | jq > ${X_IMPORT_DIR}/${E}__targetservers.json
done


