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

# ask for confirmation (skip with QUIET_INSTALL=true)
ask_confirm

echo "🗑️ Delete Apigee hybrid cluster"

yes | gcloud container clusters delete "$GKE_CLUSTER_NAME" --region "$REGION"

for disk_zone in $(echo "$ZONE" | tr "," " "); do
   for persistent_disk in $(gcloud compute disks list --format="value(name)" --filter="name~^gke-"); do
      gcloud compute disks delete "$persistent_disk" --zone="$disk_zone" -q || echo "disk not in $disk_zone"
   done
done

for cluster in $(gcloud container hub memberships list --format="value(name)"); do
   gcloud container hub memberships delete "$cluster" -q
done

echo "✅ Apigee hybrid cluster deleted"

echo "🗑️ Clean up Networking"

gcloud compute addresses delete "$INGRESS_IP_NAME" --region "$REGION" -q || echo "No regional IP address"
gcloud compute addresses delete "$INGRESS_IP_NAME" --global -q || echo "No global IP address"

for target_pool in $(gcloud compute target-pools list --format="value(name)"); do
   gcloud compute target-pools delete "$target_pool" --region "$REGION" -q
done

touch empty-file
gcloud dns record-sets import -z apigee-dns-zone \
   --delete-all-existing \
   empty-file
rm empty-file

gcloud dns managed-zones delete apigee-dns-zone -q


for fwdrule in $(gcloud compute forwarding-rules list --format="value(name)" --filter="name~xlb-apigee-$ENV_GROUP_NAME"); do
   gcloud compute forwarding-rules delete --global "$fwdrule" -q
done

for fwdrule in $(gcloud compute forwarding-rules list --format="value(name)" --regions="$REGION"); do
   gcloud compute forwarding-rules delete --region="$REGION" "$fwdrule" -q
done

for targetproxy in $(gcloud compute target-https-proxies list --format="value(name)" --filter="name~xlb-apigee-$ENV_GROUP_NAME"); do
   gcloud compute target-https-proxies delete "$targetproxy" -q
done

for targetpool in $(gcloud compute target-pools list --format="value(name)"); do
   gcloud compute target-pools delete "$targetpool" --region="$REGION" -q
done

for urlmap in $(gcloud compute url-maps list --format="value(name)" --filter="name~xlb-apigee-$ENV_GROUP_NAME"); do
   gcloud compute url-maps delete "$urlmap" -q
done

for backendsystem in $(gcloud compute backend-services list --format="value(name)" --filter="name~apigee-devrel-ingressgateway"); do
   gcloud compute backend-services delete --global "$backendsystem" -q
done

for mcrt in $(gcloud compute ssl-certificates list --format="value(name)" --filter="name~^mcrt-"); do
   gcloud compute ssl-certificates delete "$mcrt" -q
done

for firewall in $(gcloud compute firewall-rules list --filter="name~^k8s-fw-" --format='get(name)'); do
   gcloud compute  firewall-rules delete "$firewall" -q
done

for hcfirewall in $(gcloud compute firewall-rules list --filter='name~-hc$' --format='get(name)'); do
   gcloud compute  firewall-rules delete "$hcfirewall" -q
done

for firewall in $(gcloud compute firewall-rules list --filter="name~^$NETWORK" --format='get(name)'); do
   gcloud compute  firewall-rules delete "$firewall" -q
done

if [ -n "$(gcloud compute routers nats list --region "$REGION" --router "rt-$REGION" --format json --format='get(name)')" ]; then
   gcloud compute routers nats delete "apigee-nat-$REGION" --router "rt-$REGION"  -q
fi

if [ -n "$(gcloud compute routers list --format json --filter "name=rt-$REGION" --format='get(name)')" ]; then
   gcloud compute routers delete "rt-$REGION" -q
fi

echo "✅ Apigee networking cleaned up"

rm -r "$QUICKSTART_TOOLS"
rm -r "$HYBRID_HOME"

echo "✅ Tooling and Config removed"

delete_apigee_keys
delete_sa_keys "$GKE_CLUSTER_NAME-anthos"

echo "✅ SA keys deleted"


echo "✅ ✅ ✅ Clean up completed"