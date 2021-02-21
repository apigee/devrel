#!/bin/bash
# shellcheck disable=SC2059,SC2016

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
set -x

if [ -z "$PROJECT" ]; then
   echo "ERROR: Environment variable PROJECT is not set."
   exit 1
fi


# Step 1: Define functions and environment variables
function token { echo -n "$(gcloud config config-helper --force-auth-refresh | grep access_token | grep -o -E '[^ ]+$')" ; }

PROJECT_NUMBER=$(gcloud projects describe "$PROJECT" --format="value(projectNumber)")
export PROJECT_NUMBER

export NETWORK=${NETWORK:-default}
export SUBNET=${SUBNET:-default}

export REGION=${REGION:-europe-west1}
export ZONE=${ZONE:-europe-west1-b}
export AX_REGION=${AX_REGION:-europe-west1}

export ORG=$PROJECT

export MIG=apigee-envoy-$REGION

# 
export RUNTIME_SSL_CERT=~/mig-cert.pem
export RUNTIME_SSL_KEY=~/mig-key.pem
export RUNTIME_HOST_ALIAS=$ORG-eval.apigee.net


# Step 2: Enable APIs
gcloud services enable apigee.googleapis.com servicenetworking.googleapis.com compute.googleapis.com cloudkms.googleapis.com --project="$PROJECT"



# Step 4: Configure service networking

# 1. Define a range of reserved IP addresses for your network. Global
set +e
gcloud compute addresses create google-svcs --global --prefix-length=16 --description="Peering range for Google services" --network=default --purpose=VPC_PEERING --project="$PROJECT"
set -e

# 2. Connect your project's network to the Service Networking API via VPC peering
gcloud services vpc-peerings connect --service=servicenetworking.googleapis.com --network=default --ranges=google-svcs --project="$PROJECT"

## 4. Create a new eval org using the following command:

gcloud alpha apigee organizations provision \
  --runtime-location="$REGION" \
  --analytics-region="$AX_REGION" \
  --authorized-network=default \
  --project="$PROJECT"


# Step 7: Configure routing, EXTERNAL
# https://cloud.google.com/apigee/docs/api-platform/get-started/install-cli#external

# Step 7a: Enable Private Google Access
# https://cloud.google.com/vpc/docs/configure-private-google-access#gcloud_2

# enable Private Google Access:
gcloud compute networks subnets update "$SUBNET" \
--region="$REGION" \
--enable-private-ip-google-access --project "$PROJECT"

# Step 7b: Set up environment variables
# export APIGEE_ENDPOINT=eval-$REGION
APIGEE_ENDPOINT=$(curl --silent -H "Authorization: Bearer $(token)"  -X GET -H "Content-Type:application/json" https://apigee.googleapis.com/v1/organizations/"$ORG"/instances/eval-"$REGION"|jq .host --raw-output)
export APIGEE_ENDPOINT

# Step 7c: Launch the Envoy proxy

# 1. Create an instance template
gcloud compute instance-templates create "$MIG" \
  --region "$REGION" --network "$NETWORK" \
  --subnet "$SUBNET" \
  --tags=https-server,apigee-envoy-proxy,gke-apigee-proxy \
  --machine-type n1-standard-1 --image-family centos-7 \
  --image-project centos-cloud --boot-disk-size 20GB \
  --metadata ENDPOINT="$APIGEE_ENDPOINT",startup-script-url=gs://apigee-5g-saas/apigee-envoy-proxy-release/latest/conf/startup-script-envoy.sh --project "$PROJECT"

# 2. Create a managed instance group 
gcloud compute instance-groups managed create "$MIG" \
  --base-instance-name apigee-envoy \
  --size 2 --template "$MIG" --region "$REGION" --project "$PROJECT"

# 3. Configure autoscaling for the group 
gcloud compute instance-groups managed set-autoscaling "$MIG" \
  --region "$REGION" --max-num-replicas 20 \
  --target-cpu-utilization 0.75 --cool-down-period 90 --project "$PROJECT"

# 4. Defined a named port

gcloud compute instance-groups managed set-named-ports "$MIG" \
  --region "$REGION" --named-ports https:443 --project "$PROJECT"

# Step 7d: Create firewall rules

# 1. Reserve an IP address for the Load Balancer
gcloud compute addresses create lb-ipv4-vip-1 --ip-version=IPV4 --global --project "$PROJECT"

# 2. Get a reserved IP address 
RUNTIME_IP=$(gcloud compute addresses describe lb-ipv4-vip-1 --format="get(address)" --global --project "$PROJECT")
export RUNTIME_IP

# 3. Create a firewall rule that lets the Load Balancer access Envoy
gcloud compute firewall-rules create k8s-allow-lb-to-apigee-envoy \
  --description "Allow incoming from GLB on TCP port 443 to Apigee Proxy" \
  --network "$NETWORK" --allow=tcp:443 \
  --source-ranges=130.211.0.0/22,35.191.0.0/16 --target-tags=gke-apigee-proxy --project "$PROJECT"

# Step 7e: Upload credentials
# 1. Generate a certificate and key. 

openssl req -x509 -out $RUNTIME_SSL_CERT -keyout $RUNTIME_SSL_KEY -newkey rsa:2048 -nodes -sha256 -subj '/CN='"$RUNTIME_HOST_ALIAS"'' -extensions EXT -config <( printf "[dn]\nCN=$RUNTIME_HOST_ALIAS\n[req]\ndistinguished_name=dn\n[EXT]\nbasicConstraints=critical,CA:TRUE,pathlen:1\nsubjectAltName=DNS:$RUNTIME_HOST_ALIAS\nkeyUsage=digitalSignature,keyCertSign\nextendedKeyUsage=serverAuth")

# 2. Upload your SSL server certificate and key to GCP
gcloud compute ssl-certificates create apigee-ssl-cert \
  --certificate=$RUNTIME_SSL_CERT \
  --private-key=$RUNTIME_SSL_KEY --project "$PROJECT"

# Step 7f: Create a global Load Balancer

# 1. Create a health check:
gcloud compute health-checks create https hc-apigee-envoy-443 \
  --port 443 --global \
  --request-path /healthz/ingress --project "$PROJECT"

# 2. Create a backend service called "apigee-envoy-backend"

gcloud compute backend-services create apigee-envoy-backend \
  --protocol HTTPS --health-checks hc-apigee-envoy-443 \
  --port-name https --timeout 60s --connection-draining-timeout 300s --global --project "$PROJECT"

# 3. Add the Envoy instance group to your backend service
gcloud compute backend-services add-backend apigee-envoy-backend \
  --instance-group "$MIG" \
  --instance-group-region "$REGION" \
  --balancing-mode UTILIZATION --max-utilization 0.8 --global --project "$PROJECT"

# 4. Create a Load Balancing URL map
gcloud compute url-maps create apigee-envoy-proxy-map \
  --default-service apigee-envoy-backend --project "$PROJECT"

# 5. Create a Load Balancing target HTTPS proxy 
gcloud compute target-https-proxies create apigee-envoy-https-proxy \
  --url-map apigee-envoy-proxy-map \
  --ssl-certificates apigee-ssl-cert --project "$PROJECT"

# 6. Create a global forwarding rule
gcloud compute forwarding-rules create apigee-envoy-https-lb-rule \
  --address lb-ipv4-vip-1 --global \
  --target-https-proxy apigee-envoy-https-proxy --ports 443 --project "$PROJECT"

## TODO: [ ] wait till LB is ready


echo ""
echo "# To send a test request, execute following commands:"
echo ""
echo "export RUNTIME_IP=$RUNTIME_IP"

echo "export RUNTIME_SSL_CERT=~/mig-cert.pem"
echo "export RUNTIME_SSL_KEY=~/mig-key.pem"
echo "export RUNTIME_HOST_ALIAS=$RUNTIME_HOST_ALIAS"

echo 'curl --cacert $RUNTIME_SSL_CERT https://$RUNTIME_HOST_ALIAS/hello-world -v --resolve "$RUNTIME_HOST_ALIAS:443:$RUNTIME_IP"'

