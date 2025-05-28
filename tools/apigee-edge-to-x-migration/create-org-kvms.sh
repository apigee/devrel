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
echo $EXPORTED_ORG_DIR
echo $X_IMPORT_DIR

# Org level
KVMS=$(ls $EXPORTED_ORG_DIR/kvm/org)
for KVM in $KVMS
do
    echo KVM: ${EXPORTED_ORG_DIR}/kvm/org/${KVM} TO: ${X_IMPORT_DIR}/org__${KVM}__kvmfile__0.json
    python3 ${APIGEE_MIGRATE_EDGE_TO_X_TOOLS_DIR}/convert-kvms-edge-x.py ${EXPORTED_ORG_DIR}/kvm/org/${KVM} | jq > ${X_IMPORT_DIR}/org__${KVM}__kvmfile__0.json
done
