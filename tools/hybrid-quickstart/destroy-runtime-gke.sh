#!/bin/bash

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

QUICKSTART_ROOT="$( cd "$(dirname "$0")" || exit >/dev/null 2>&1 ; pwd -P )"
export QUICKSTART_ROOT

source "$QUICKSTART_ROOT/steps.sh"

set_config_params

echo "🗑️ Delete Apigee hybrid cluster"

gcloud container hub memberships unregister "$GKE_CLUSTER_NAME" --gke-cluster="${ZONE}/${GKE_CLUSTER_NAME}"
yes | gcloud container clusters delete "$GKE_CLUSTER_NAME"

echo "✅ Apigee hybrid cluster deleted"


echo "🗑️ Clean up Networking"

gcloud compute addresses delete apigee-ingress-ip --region "$REGION" -q

touch empty-file
gcloud dns record-sets import -z apigee-dns-zone \
   --delete-all-existing \
   empty-file
rm empty-file

gcloud dns managed-zones delete apigee-dns-zone -q

echo "✅ Apigee networking cleaned up"

rm -r "$QUICKSTART_TOOLS"
rm -r "$HYBRID_HOME"

echo "✅ Tooling and Config removed"

delete_apigee_keys
delete_sa_keys "$GKE_CLUSTER_NAME-anthos"

echo "✅ SA keys deleted"


echo "✅ ✅ ✅ Clean up completed"