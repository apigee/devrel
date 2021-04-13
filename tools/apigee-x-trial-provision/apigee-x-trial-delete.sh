#!/bin/bash

# Copyright 2020 Google LLC
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


# options
pps=""
while(($#)); do
case "$1" in
  -p|--project)
    PROJECT="$2"
    shift 2;;

  -q|--quiet)
    QUIET=Y
    shift;;

  --delete-org)
    DELETE_APIGEE_ORG=Y
    shift;;

  *)
    pps="$pps $1"
    shift;;
esac
done
eval set -- "$pps"

if [ -z "$PROJECT" ]; then
   >&2 echo "ERROR: Environment variable PROJECT is not set."
   >&2 echo "       export PROJECT=<your-gcp-project-name>"
   exit 1
fi

if ! [ -x "$(command -v jq)" ]; then
  >&2 echo "ABORTED: Required command is not on your PATH: jq."
  >&2 echo "         Please install it before you continue."
  exit 2
fi

if [ ! "$QUIET" = "Y" ]; then
  read -p "Are you sure you want to delete your entire Apigee trial setup? [y/N]: " -n 1 -r REPLY; printf "\n"
  REPLY=${REPLY:-Y}

  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    echo "starting deletion (run with flag --delete-org to also delete the Apigee Organization)"
  else
    exit 1
  fi
fi

gcloud compute forwarding-rules delete apigee-proxy-https-lb-rule --global -q --project "$PROJECT" || echo ""
gcloud compute target-https-proxies delete apigee-proxy-https-proxy -q --project "$PROJECT"
gcloud compute url-maps delete apigee-proxy-map -q --project "$PROJECT"
gcloud compute backend-services delete apigee-proxy-backend --global -q --project "$PROJECT"
gcloud compute health-checks delete hc-apigee-proxy-443 --global -q --project "$PROJECT"
gcloud compute ssl-certificates delete apigee-ssl-cert --global -q --project "$PROJECT"
gcloud compute firewall-rules delete k8s-allow-lb-to-apigee-proxy -q --project "$PROJECT"
gcloud compute addresses delete lb-ipv4-vip-1 --global -q --project "$PROJECT"

INSTANCE_GROUP_RESPONSE="$(gcloud compute instance-groups managed list --format="json" --project "$PROJECT")"
gcloud compute instance-groups managed delete "$(echo "$INSTANCE_GROUP_RESPONSE" | jq -r '.[0].name')" \
  --region "$(echo "$INSTANCE_GROUP_RESPONSE" | jq -r '.[0].region')" -q --project "$PROJECT"

INSTANCE_TEMPLATE_RESPONSE="$(gcloud compute instance-templates list --format="json" --project "$PROJECT")"
gcloud compute instance-templates delete "$(echo "$INSTANCE_TEMPLATE_RESPONSE" | jq -r '.[0].name')" -q --project "$PROJECT"

if [ "$DELETE_APIGEE_ORG" = "Y" ]; then
    gcloud alpha apigee organizations delete "$PROJECT" --project "$PROJECT"
    gcloud compute addresses delete google-managed-services-default --global -q --project "$PROJECT"
fi