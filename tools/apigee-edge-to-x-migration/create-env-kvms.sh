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
echo $ENVS
echo $APIGEE_MIGRATE_EDGE_TO_X_TOOLS_DIR
echo $EDGE_EXPORT_DIR
echo $X_IMPORT_DIR

for E in $ENVS
do
    export EXPORTED_DIR=$EDGE_EXPORT_DIR/data-env-${E}/kvm/env/$E
    echo $E
    KVMS=$(ls $EXPORTED_DIR)
    # KVMS="pingstatus-v1 pingstatus-oauth-v1 oauth-v1 oauth-v1-jwt-key"

    for KVM in $KVMS
    do
        # ls -l ${EXPORTED_DIR}/${KVM}
        
        echo Env $E KVM: ${EXPORTED_DIR}/${KVM} TO: ${IMPORT_DIR}/env__${E}__${KVM}__kvmfile__0.json
        python3 ${APIGEE_MIGRATE_EDGE_TO_X_TOOLS_DIR}/convert-kvms-edge-x.py ${EXPORTED_DIR}/${KVM} | jq > ${X_IMPORT_DIR}/env__${E}__${KVM}__kvmfile__0.json
    done
done


