#!/bin/bash

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

export EDGE_X_MIGRATION_DIR=$HOME/work/APIGEEX/edge-x-migration

# Edge variables
export EDGE_ORG=your_edge_org_name
export ENVS="env1 env2"
export B64UNPW="base64 of your_username:your_password"
export EDGE_AUTH="Authorization: Basic $B64UNPW"

export EDGE_EXPORT_DIR=$EDGE_X_MIGRATION_DIR/edge-export
mkdir $EDGE_EXPORT_DIR
export EXPORTED_ORG_DIR=$EDGE_EXPORT_DIR/data-org-${EDGE_ORG}

# X variables
export X_ORG=your_x_org_name
export X_IMPORT_DIR=$EDGE_X_MIGRATION_DIR/x-import
mkdir $X_IMPORT_DIR

# Other variables
export APIGEE_MIGRATE_EDGE_TO_X_TOOLS_DIR=$EDGE_X_MIGRATION_DIR/devrel/tools/apigee-migrate-edge-to-x-tools
export APIGEE_MIGRATE_TOOL_DIR=$EDGE_X_MIGRATION_DIR/apigee-migrate-tool