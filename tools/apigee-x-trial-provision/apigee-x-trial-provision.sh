#!/bin/bash
# shellcheck disable=SC2059,SC2016,SC2181

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

set -e

if ! [ -x "$(command -v jq)" ]; then
  >&2 echo "ABORTED: Required command is not on your PATH: jq."
  >&2 echo "         Please install it before continue."

  exit 2
fi


if [ -z "$PROJECT" ]; then
   >&2 echo "ERROR: Environment variable PROJECT is not set."
   >&2 echo "       export PROJECT=<your-gcp-project-name>"
   exit 1
fi


# Step 1: Define functions and environment variables
function token { echo -n "$(gcloud config config-helper --force-auth-refresh | grep access_token | grep -o -E '[^ ]+$')" ; }


export ORG=$PROJECT

echo "CHECK: Checking if organization $ORG is already provisioned"
ORG_JSON=$(curl --silent -H "Authorization: Bearer $(token)"  -X GET -H "Content-Type:application/json" https://apigee.googleapis.com/v1/organizations/"$ORG")

APIGEE_PROVISIONED="F"
if [ "ACTIVE" = "$(echo "$ORG_JSON" | jq --raw-output .state)" ]; then
  APIGEE_PROVISIONED="T"


  echo "Apigee Organization exists and is active"

  echo "Taking AX_REGION, LOCATION, and .... from Organization Configuration "

  NETWORK=$(echo "$ORG_JSON" | jq --raw-output .authorizedNetwork)
  AX_REGION=$(echo "$ORG_JSON" | jq --raw-output .analyticsRegion)

# TODO: [ ] right now single instance is expected
  ZONE=$(curl --silent -H "Authorization: Bearer $(token)"  -X GET -H "Content-Type:application/json" https://apigee.googleapis.com/v1/organizations/"$ORG"/instances|jq --raw-output '.instances[0].location')
  
  echo "Deriving REGION from ZONE, as Envoy instances should be in the same region as your Apigee runtime instance"
  REGION=$(echo "$ZONE" | awk '{gsub(/-[a-z]+$/,"");print}')
else
  echo "Didn't find an active Apigee Organization. Using environment variable defaults"
  
  REGION=${REGION:-europe-west1}
  NETWORK=${NETWORK:-default}
  
  ZONE=${ZONE:-europe-west1-b}
  AX_REGION=${AX_REGION:-europe-west1}
fi

export NETWORK
export REGION
export ZONE
export AX_REGION

export SUBNET=${SUBNET:-default}

echo "Resolved Configuration: "
echo "  NETWORK=$NETWORK"
echo "  REGION=$REGION"
echo "  ZONE=$ZONE"
echo "  AX_REGION=$AX_REGION"
echo ""

export MIG=apigee-envoy-$REGION

# 
export RUNTIME_SSL_CERT=${RUNTIME_SSL_CERT:-~/mig-cert.pem}
export RUNTIME_SSL_KEY=${RUNTIME_SSL_KEY:-~/mig-key.pem}
export RUNTIME_HOST_ALIAS=${RUNTIME_HOST_ALIAS:-$ORG-eval.apigee.net}


echo "Validation: valid zone value: $ZONE"
CHECK_ZONE=$(gcloud compute zones list --filter="name=( \"$ZONE\" )" --format="table[no-heading](name)" --project="$PROJECT")
if [ "$ZONE" != "$CHECK_ZONE" ]; then
  echo "ERROR: zone value is invalid: $ZONE"
  exit
fi

echo "Step 2: Enable APIs"
gcloud services enable apigee.googleapis.com servicenetworking.googleapis.com compute.googleapis.com cloudkms.googleapis.com --project="$PROJECT"

if [ "$APIGEE_PROVISIONED" = "T" ]; then

  echo "Apigee Organization is already provisioned."
  echo "Reserved IP addresses for network $NETWORK:"
  gcloud compute addresses list --project "$PROJECT"

  echo ""
  echo "Skipping Service networking and Organization Provisioning steps."
else

echo "Step 4: Configure service networking"

echo "Step 4.1: Define a range of reserved IP addresses for your network. "
set +e
OUTPUT=$(gcloud compute addresses create google-managed-services-default --global --prefix-length=16 --description="Peering range for Google services" --network="$NETWORK" --purpose=VPC_PEERING --project="$PROJECT" 2>&1 )
if [ "$?" != 0 ]; then
   if [[ "$OUTPUT" =~ " already exists" ]]; then
      echo "google-managed-services-default already exists"
      set -e
   else
      echo "$OUTPUT"
      exit 1
   fi
fi

echo "Step 4.2: Connect your project's network to the Service Networking API via VPC peering"
gcloud services vpc-peerings connect --service=servicenetworking.googleapis.com --network="$NETWORK" --ranges=google-managed-services-default --project="$PROJECT"

echo "Step 4.4: Create a new eval org [it takes time, 10-20 minutes. please wait...]"

set +e
gcloud alpha apigee organizations provision \
  --runtime-location="$ZONE" \
  --analytics-region="$AX_REGION" \
  --authorized-network="$NETWORK" \
  --project="$PROJECT"
set -e


fi  # for Step 4: Configure service networking

echo ""
echo "Step 7: Configure routing, EXTERNAL"
# https://cloud.google.com/apigee/docs/api-platform/get-started/install-cli#external

echo "Step 7a: Enable Private Google Access"
# https://cloud.google.com/vpc/docs/configure-private-google-access#gcloud_2

echo "# enable Private Google Access"
gcloud compute networks subnets update "$SUBNET" \
--region="$REGION" \
--enable-private-ip-google-access --project "$PROJECT"

echo "Step 7b: Set up environment variables"
# export APIGEE_ENDPOINT=eval-$ZONE
APIGEE_ENDPOINT=$(curl --silent -H "Authorization: Bearer $(token)"  -X GET -H "Content-Type:application/json" https://apigee.googleapis.com/v1/organizations/"$ORG"/instances/eval-"$ZONE"|jq .host --raw-output)
export APIGEE_ENDPOINT

echo "Check that APIGEE_ENDPOINT is not null: $APIGEE_ENDPOINT"
if [ "$APIGEE_ENDPOINT" == "null" ]; then
  echo "ERROR: Something is wrong with your Location configuration, as APIGEE_ENDPOINT is equal null"
  exit 1
fi


echo "Step 7c: Launch the Envoy proxy"

echo "Step 7c.1: Create an instance template"

gcloud compute instance-templates create "$MIG" \
  --region "$REGION" --network "$NETWORK" \
  --subnet "$SUBNET" \
  --tags=https-server,apigee-envoy-proxy,gke-apigee-proxy \
  --machine-type n1-standard-1 --image-family centos-7 \
  --image-project centos-cloud --boot-disk-size 20GB \
  --metadata ENDPOINT="$APIGEE_ENDPOINT",startup-script-url=gs://apigee-5g-saas/apigee-envoy-proxy-release/latest/conf/startup-script-envoy.sh --project "$PROJECT"

echo "Step 7c.2: Create a managed instance group"
gcloud compute instance-groups managed create "$MIG" \
  --base-instance-name apigee-envoy \
  --size 2 --template "$MIG" --region "$REGION" --project "$PROJECT"

echo "Step 7c.3: Configure autoscaling for the group"
gcloud compute instance-groups managed set-autoscaling "$MIG" \
  --region "$REGION" --max-num-replicas 20 \
  --target-cpu-utilization 0.75 --cool-down-period 90 --project "$PROJECT"

echo "Step 7c.4: Defined a named port"

gcloud compute instance-groups managed set-named-ports "$MIG" \
  --region "$REGION" --named-ports https:443 --project "$PROJECT"

echo "Step 7d: Create firewall rules"

set +e

echo "Step 7d.1: Reserve an IP address for the Load Balancer"
gcloud compute addresses create lb-ipv4-vip-1 --ip-version=IPV4 --global --project "$PROJECT"

echo "Step 7d.2: Get a reserved IP address"
RUNTIME_IP=$(gcloud compute addresses describe lb-ipv4-vip-1 --format="get(address)" --global --project "$PROJECT")
export RUNTIME_IP

echo "Step 7d.3: Create a firewall rule that lets the Load Balancer access Envoy"
gcloud compute firewall-rules create k8s-allow-lb-to-apigee-envoy \
  --description "Allow incoming from GLB on TCP port 443 to Apigee Proxy" \
  --network "$NETWORK" --allow=tcp:443 \
  --source-ranges=130.211.0.0/22,35.191.0.0/16 --target-tags=gke-apigee-proxy --project "$PROJECT"

set -e

echo "Step 7e: Upload credentials:"
echo "Step 7e.1: Generate a certificate and key"

echo "Check if certificate and key already exist..."
if [[ -f "$RUNTIME_SSL_CERT" ]]; then
    echo "Certificate $RUNTIME_SSL_CERT already exists."
    SSL_CERT_EXISTS="T"
fi
if [[ -f "$RUNTIME_SSL_KEY" ]]; then
    echo "Key $RUNTIME_SSL_KEY already exists."
    SSL_KEY_EXISTS="T"
fi
if [ "$SSL_CERT_EXISTS" = "T" ] && [ "$SSL_KEY_EXISTS" = "T" ]; then
  echo ""
  echo "Certificate $RUNTIME_SSL_CERT and Key $RUNTIME_SSL_KEY exit. Using them"
else
  echo "Generate eval certificate and key"

  openssl req -x509 -out "$RUNTIME_SSL_CERT" -keyout "$RUNTIME_SSL_KEY" -newkey rsa:2048 -nodes -sha256 -subj '/CN='"$RUNTIME_HOST_ALIAS"'' -extensions EXT -config <( printf "[dn]\nCN=$RUNTIME_HOST_ALIAS\n[req]\ndistinguished_name=dn\n[EXT]\nbasicConstraints=critical,CA:TRUE,pathlen:1\nsubjectAltName=DNS:$RUNTIME_HOST_ALIAS\nkeyUsage=digitalSignature,keyCertSign\nextendedKeyUsage=serverAuth")

fi

echo "Step 7e.2: Upload your SSL server certificate and key to GCP"
gcloud compute ssl-certificates create apigee-ssl-cert \
  --certificate="$RUNTIME_SSL_CERT" \
  --private-key="$RUNTIME_SSL_KEY" --project "$PROJECT"

echo "Step 7f: Create a global Load Balancer"

echo "Step 7f.1: Create a health check"
gcloud compute health-checks create https hc-apigee-envoy-443 \
  --port 443 --global \
  --request-path /healthz/ingress --project "$PROJECT"

echo "Step 7f.2: Create a backend service called 'apigee-envoy-backend'"

gcloud compute backend-services create apigee-envoy-backend \
  --protocol HTTPS --health-checks hc-apigee-envoy-443 \
  --port-name https --timeout 60s --connection-draining-timeout 300s --global --project "$PROJECT"

echo "Step 7f.3: Add the Envoy instance group to your backend service"
gcloud compute backend-services add-backend apigee-envoy-backend \
  --instance-group "$MIG" \
  --instance-group-region "$REGION" \
  --balancing-mode UTILIZATION --max-utilization 0.8 --global --project "$PROJECT"

echo "Step 7f.4: Create a Load Balancing URL map"
gcloud compute url-maps create apigee-envoy-proxy-map \
  --default-service apigee-envoy-backend --project "$PROJECT"

echo "Step 7f.5: Create a Load Balancing target HTTPS proxy"
gcloud compute target-https-proxies create apigee-envoy-https-proxy \
  --url-map apigee-envoy-proxy-map \
  --ssl-certificates apigee-ssl-cert --project "$PROJECT"

echo "Step 7f.6: Create a global forwarding rule"
gcloud compute forwarding-rules create apigee-envoy-https-lb-rule \
  --address lb-ipv4-vip-1 --global \
  --target-https-proxy apigee-envoy-https-proxy --ports 443 --project "$PROJECT"

# TODO: [ ] wait till LB is ready
echo ""
echo "Almost done. It take some time (another 5-8 minutes) to provision load balancer infrastructure."
echo ""

echo ""
echo "# To send an INTERNAL test request (from a VM at the private network)"
echo " copy $RUNTIME_SSL_CERT and execute following commands:"
echo ""
echo "export RUNTIME_IP=$APIGEE_ENDPOINT"

echo "export RUNTIME_SSL_CERT=~/mig-cert.pem"
echo "export RUNTIME_HOST_ALIAS=$RUNTIME_HOST_ALIAS"

echo 'curl --cacert $RUNTIME_SSL_CERT https://$RUNTIME_HOST_ALIAS/hello-world -v --resolve "$RUNTIME_HOST_ALIAS:443:$RUNTIME_IP"'
echo ""
echo "You can also skip server certificate validation for testing purposes:"

echo 'curl -k https://$RUNTIME_HOST_ALIAS/hello-world -v --resolve "$RUNTIME_HOST_ALIAS:443:$RUNTIME_IP"'
echo ""

echo ""
echo "# To send a EXTERNAL test request, execute following commands:"
echo ""
echo "export RUNTIME_IP=$RUNTIME_IP"

echo "export RUNTIME_SSL_CERT=~/mig-cert.pem"
echo "export RUNTIME_HOST_ALIAS=$RUNTIME_HOST_ALIAS"

echo 'curl --cacert $RUNTIME_SSL_CERT https://$RUNTIME_HOST_ALIAS/hello-world -v --resolve "$RUNTIME_HOST_ALIAS:443:$RUNTIME_IP"'

