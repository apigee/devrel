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

# options
pps=""
while(($#)); do
case "$1" in
  -p|--project)
    PROJECT="$2"
    shift 2;;

  -n|--network)
    NETWORK="$2"
    shift 2;;

  -r|--region)
    REGION="$2"
    shift 2;;

  -x|--ax-region)
    AX_REGION="$2"
    shift 2;;

  -c|--certificates)
    CERTIFICATES="$2"
    shift 2;;

  -q|--quiet)
    QUIET=Y
    shift;;

  --shared-vpc-host-config)
    SHARED_HOST_ONLY=Y
    shift;;

  --peering-cidr)
    PEERING_CIDR="$2"
    shift 2;;

  *)
    pps="$pps $1"
    shift;;
esac
done
eval set -- "$pps"

for dependency in jq openssl
do
  if ! [ -x "$(command -v $dependency)" ]; then
    >&2 echo "ABORTED: Required command is not on your PATH: $dependency."
    >&2 echo "         Please install it before you continue."
    exit 2
  fi
done

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

  echo "Taking AX_REGION, LOCATION, and NETWORK from existing Organization Configuration"

  NETWORK=$(echo "$ORG_JSON" | jq --raw-output .authorizedNetwork)
  AX_REGION=$(echo "$ORG_JSON" | jq --raw-output .analyticsRegion)

# TODO: [ ] right now single instance is expected
  ZONE=$(curl --silent -H "Authorization: Bearer $(token)"  -X GET -H "Content-Type:application/json" https://apigee.googleapis.com/v1/organizations/"$ORG"/instances|jq --raw-output '.instances[0].location')

  echo "Deriving REGION from ZONE, as Proxy instances should be in the same region as your Apigee runtime instance"
  REGION=$(echo "$ZONE" | awk '{gsub(/-[a-z]+$/,"");print}')
else
  echo "Didn't find an active Apigee Organization. Using environment variable defaults"

  REGION=${REGION:-europe-west1}
  NETWORK=${NETWORK:-default}
  AX_REGION=${AX_REGION:-europe-west1}
fi

export NETWORK
export REGION
export AX_REGION
export SUBNET=${SUBNET:-default}
export PROXY_MACHINE_TYPE=${PROXY_MACHINE_TYPE:-e2-micro}
export PROXY_PREEMPTIBLE=${PROXY_PREEMPTIBLE:-false}
export PROXY_MIG_MIN_SIZE=${PROXY_MIG_MIN_SIZE:-1}
export CERTIFICATES=${CERTIFICATES:-managed}
export ENV_GROUP_NAME='eval-group'

CERT_DISPLAY=$CERTIFICATES

if [ "$CERTIFICATES" = "provided" ];then
  if [ -f "$RUNTIME_TLS_KEY" ] && [ -f "$RUNTIME_TLS_CERT" ]; then
    CERT_DISPLAY="$CERT_DISPLAY key: $RUNTIME_TLS_KEY, cert $RUNTIME_TLS_CERT"
  else
    echo "you selected CERTIFICATES=$CERTIFICATES but RUNTIME_TLS_KEY and/or RUNTIME_TLS_CERT is missing"
    exit 1
  fi
fi

if [ -z "$PEERING_CIDR" ]; then
  PEERING_CIDR_DISPLAY="[automatic /23 block]"
else
  PEERING_CIDR_DISPLAY="$PEERING_CIDR"
fi

if [ "$CERTIFICATES" = "managed" ]; then
  export RUNTIME_HOST_ALIAS="$ENV_GROUP_NAME.[external-ip].nip.io"
else
  export RUNTIME_HOST_ALIAS=${RUNTIME_HOST_ALIAS:-$ORG-eval.apigee.net}
fi

echo ""
echo "Resolved Configuration: "
echo "  PROJECT=$PROJECT"
echo "  NETWORK=$NETWORK"
echo "  SUBNET=$SUBNET"
echo "  PEERING_CIDR=$PEERING_CIDR_DISPLAY"
if [ "$SHARED_HOST_ONLY" = "Y" ]; then
  echo "provisioning shared VPC host project only"
else
  echo "  ORG=$ORG"
  echo "  REGION=$REGION"
  echo "  AX_REGION=$AX_REGION"
  echo "  PROXY_MACHINE_TYPE=$PROXY_MACHINE_TYPE"
  echo "  PROXY_PREEMPTIBLE=$PROXY_PREEMPTIBLE"
  echo "  PROXY_MIG_MIN_SIZE=$PROXY_MIG_MIN_SIZE"
  echo "  CERTIFICATES=$CERT_DISPLAY"
  echo "  RUNTIME_HOST_ALIAS=$RUNTIME_HOST_ALIAS"
fi
echo ""

if [ ! "$QUIET" = "Y" ]; then
  read -p "Do you want to continue with the config above? [Y/n]: " -n 1 -r REPLY; printf "\n"
  REPLY=${REPLY:-Y}

  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    echo "starting provisioning"
  else
    exit 1
  fi
fi

echo "Step 2: Enable APIs"
gcloud services enable apigee.googleapis.com compute.googleapis.com cloudresourcemanager.googleapis.com servicenetworking.googleapis.com cloudkms.googleapis.com --project="$PROJECT" --quiet

echo "Step 4: Configure service networking"

if [[ "$NETWORK" =~ ^projects/.*/networks.*$ ]]; then
  set +e
  gcloud compute networks describe "$NETWORK" --project "$PROJECT" --quiet | grep -q "$SUBNET"
  SUBNET_FOUND=$?
  set -e
  if [ "$SUBNET_FOUND" = "0" ]; then
    echo "using existing shared VPC subnet $SUBNET"
  else
    echo "$SUBNET is not shared with this project"
    exit 1
  fi
else
  echo "Step 4.1: Define a range of reserved IP addresses for your network. "
  if [ -z "$PEERING_CIDR" ]; then
    gcloud compute addresses create google-managed-services-default --global --prefix-length=23 \
      --description="Peering range for Google Apigee X Tenant" --network="$NETWORK" \
      --purpose=VPC_PEERING --project="$PROJECT" --quiet || echo "Failed to create - ignoring assuming it already exists"
  else
    RANGE_START="$(echo "$PEERING_CIDR" | cut -d/ -f1)"
    RANGE_PREFIX_LENGTH="$(echo "$PEERING_CIDR" | cut -d/ -f2)"
    gcloud compute addresses create google-managed-services-default --global  --addresses="$RANGE_START" --prefix-length="$RANGE_PREFIX_LENGTH" \
      --description="Peering range for Google Apigee X Tenant" --network="$NETWORK" \
      --purpose=VPC_PEERING --project="$PROJECT" --quiet || echo "Failed to create - ignoring assuming it already exists"
  fi

  echo "Step 4.2: Connect your project's network to the Service Networking API via VPC peering"
  gcloud services vpc-peerings connect --service=servicenetworking.googleapis.com \
    --network="$NETWORK" --ranges=google-managed-services-default --project="$PROJECT"  --quiet ||
    echo "Failed to create - ignoring assuming it already exists"

  echo "Step 7d.3: Create a firewall rule that lets the Load Balancer access Proxy VM"
  gcloud compute firewall-rules create k8s-allow-lb-to-apigee-proxy \
    --description "Allow incoming from GLB on TCP port 443 to Apigee Proxy" --network "$NETWORK" \
    --allow=tcp:443 --source-ranges=130.211.0.0/22,35.191.0.0/16 --target-tags=gke-apigee-proxy \
    --project "$PROJECT" --quiet || echo "Failed to create - ignoring assuming it already exists"
fi

if [ "$SHARED_HOST_ONLY" = "Y" ]; then
  echo ""
  echo "Done provisioning shared VPC host project"
  echo "Set the following environment variable and run this script again."
  echo "export PROJECT=<your-apigee-x-service-project>"
  echo "export NETWORK=projects/$PROJECT/global/networks/$NETWORK"
  echo "export SUBNET=projects/$PROJECT/regions/$REGION/subnetworks/$SUBNET"
  echo ""
  exit 0;
fi

export MIG=apigee-proxy-$REGION

echo "Validation: valid region value: $REGION"
CHECK_REGION=$(gcloud compute regions list --filter="name=( \"$REGION\" )" --format="table[no-heading](name)" --project="$PROJECT" --quiet)
if [ "$REGION" != "$CHECK_REGION" ]; then
  echo "ERROR: region value is invalid: $REGION"
  exit
fi

if [ "$APIGEE_PROVISIONED" = "T" ]; then

  echo "Apigee Organization is already provisioned."
  echo "Reserved IP addresses for network $NETWORK:"
  gcloud compute addresses list --project "$PROJECT" --quiet

  echo ""
  echo "Skipping Service networking and Organization Provisioning steps."
else


echo "Step 4.4: Create a new eval org [it takes time, 10-20 minutes. please wait...]"

set +e
gcloud components install alpha --quiet # as the cloud-sdk image no longer has this
gcloud alpha apigee organizations provision \
  --runtime-location="$REGION" \
  --analytics-region="$AX_REGION" \
  --authorized-network="$NETWORK" \
  --project="$PROJECT" --quiet
set -e


fi # for Step 4: Configure service networking

echo ""
echo "Step 7: Configure routing, EXTERNAL"
# https://cloud.google.com/apigee/docs/api-platform/get-started/install-cli#external

echo "Step 7a: Enable Private Google Access"
# https://cloud.google.com/vpc/docs/configure-private-google-access#gcloud_2

echo "# enable Private Google Access"
gcloud compute networks subnets update "$SUBNET" \
--region="$REGION" \
--enable-private-ip-google-access --project "$PROJECT" --quiet

echo "Step 7b: Set up environment variables"
APIGEE_ENDPOINT=$(curl --silent -H "Authorization: Bearer $(token)"  -X GET -H "Content-Type:application/json" https://apigee.googleapis.com/v1/organizations/"$ORG"/instances | jq --raw-output '.instances[0].host')
export APIGEE_ENDPOINT

echo "Check that APIGEE_ENDPOINT is not null: $APIGEE_ENDPOINT"
if [ "$APIGEE_ENDPOINT" == "null" ]; then
  echo "ERROR: Something is wrong with your Location configuration, as APIGEE_ENDPOINT is equal null"
  exit 1
fi


echo "Step 7c: Launch the Load Balancer proxy VMs"

set +e # TODO: [ ] Properly handle existing GCP resources

echo "Step 7c.1: Create an instance template"

if [ "$PROXY_PREEMPTIBLE" = "true" ]; then
  PREEMPTIBLE_FLAG=" --preemptible"
fi

gcloud compute instance-templates create "$MIG" \
  --region "$REGION" --network "$NETWORK" \
  --subnet "$SUBNET" \
  --no-address \
  --tags=https-server,apigee-network-proxy,gke-apigee-proxy \
  --machine-type "$PROXY_MACHINE_TYPE""$PREEMPTIBLE_FLAG" \
  --image-family centos-7 \
  --image-project centos-cloud --boot-disk-size 20GB \
  --metadata ENDPOINT="$APIGEE_ENDPOINT",startup-script-url=gs://apigee-5g-saas/apigee-envoy-proxy-release/latest/conf/startup-script.sh --project "$PROJECT" --quiet

echo "Step 7c.2: Create a managed instance group"
gcloud compute instance-groups managed create "$MIG" \
  --base-instance-name apigee-proxy \
  --size "$PROXY_MIG_MIN_SIZE" --template "$MIG" --region "$REGION" --project "$PROJECT" --quiet

echo "Step 7c.3: Configure autoscaling for the group"
gcloud compute instance-groups managed set-autoscaling "$MIG" \
  --region "$REGION" --max-num-replicas 20 \
  --target-cpu-utilization 0.75 --cool-down-period 90 --project "$PROJECT" --quiet

echo "Step 7c.4: Defined a named port"

gcloud compute instance-groups managed set-named-ports "$MIG" \
  --region "$REGION" --named-ports https:443 --project "$PROJECT" --quiet

echo "Step 7d: Create firewall rules"


echo "Step 7d.1: Reserve an IP address for the Load Balancer"
gcloud compute addresses create lb-ipv4-vip-1 --ip-version=IPV4 --global --project "$PROJECT" --quiet

echo "Step 7d.2: Get a reserved IP address"
RUNTIME_IP=$(gcloud compute addresses describe lb-ipv4-vip-1 --format="get(address)" --global --project "$PROJECT" --quiet)
export RUNTIME_IP



echo "Step 7e: Upload credentials:"

if [ "$CERTIFICATES" = "managed" ]; then
  echo "Step 7e.1: Using Google managed certificate:"
  RUNTIME_HOST_ALIAS="$ENV_GROUP_NAME".$(echo "$RUNTIME_IP" | tr '.' '-').nip.io
  gcloud compute ssl-certificates create apigee-ssl-cert \
    --domains="$RUNTIME_HOST_ALIAS" --project "$PROJECT" --quiet
elif [ "$CERTIFICATES" = "generated" ]; then
  echo "Step 7e.1: Generate eval certificate and key"
  export RUNTIME_TLS_CERT=~/mig-cert.pem
  export RUNTIME_TLS_KEY=~/mig-key.pem
  openssl req -x509 -out "$RUNTIME_TLS_CERT" -keyout "$RUNTIME_TLS_KEY" -newkey rsa:2048 -nodes -sha256 -subj '/CN='"$RUNTIME_HOST_ALIAS"'' -extensions EXT -config <( printf "[dn]\nCN=$RUNTIME_HOST_ALIAS\n[req]\ndistinguished_name=dn\n[EXT]\nbasicConstraints=critical,CA:TRUE,pathlen:1\nsubjectAltName=DNS:$RUNTIME_HOST_ALIAS\nkeyUsage=digitalSignature,keyCertSign\nextendedKeyUsage=serverAuth")

  echo "Step 7e.2: Upload your TLS server certificate and key to GCP"
  gcloud compute ssl-certificates create apigee-ssl-cert \
    --certificate="$RUNTIME_TLS_CERT" \
    --private-key="$RUNTIME_TLS_KEY" --project "$PROJECT" --quiet
else
  echo "Step 7e.2: Upload your TLS server certificate and key to GCP"
  gcloud compute ssl-certificates create apigee-ssl-cert \
    --certificate="$RUNTIME_TLS_CERT" \
    --private-key="$RUNTIME_TLS_KEY" --project "$PROJECT" --quiet
fi

CURRENT_HOST_ALIAS=$(curl -X GET --silent -H "Authorization: Bearer $(token)"  \
    -H "Content-Type:application/json" https://apigee.googleapis.com/v1/organizations/"$ORG"/envgroups/$ENV_GROUP_NAME | jq -r '.hostnames[0]')

if [ "$RUNTIME_HOST_ALIAS" != "$CURRENT_HOST_ALIAS" ]; then
  echo "setting hostname on env group to $RUNTIME_HOST_ALIAS"
  curl -X PATCH --silent -H "Authorization: Bearer $(token)"  \
    -H "Content-Type:application/json" https://apigee.googleapis.com/v1/organizations/"$ORG"/envgroups/$ENV_GROUP_NAME \
    -d "{\"hostnames\": [\"$RUNTIME_HOST_ALIAS\"]}"
fi

echo "Step 7f: Create a global Load Balancer"

echo "Step 7f.1: Create a health check"
gcloud compute health-checks create https hc-apigee-proxy-443 \
  --port 443 --global \
  --request-path /healthz/ingress --project "$PROJECT" --quiet

echo "Step 7f.2: Create a backend service called 'apigee-proxy-backend'"

gcloud compute backend-services create apigee-proxy-backend \
  --protocol HTTPS --health-checks hc-apigee-proxy-443 \
  --port-name https --timeout 60s --connection-draining-timeout 300s --global --project "$PROJECT" --quiet

echo "Step 7f.3: Add the Load Balancer Proxy VM instance group to your backend service"
gcloud compute backend-services add-backend apigee-proxy-backend \
  --instance-group "$MIG" \
  --instance-group-region "$REGION" \
  --balancing-mode UTILIZATION --max-utilization 0.8 --global --project "$PROJECT" --quiet

echo "Step 7f.4: Create a Load Balancing URL map"
gcloud compute url-maps create apigee-proxy-map \
  --default-service apigee-proxy-backend --project "$PROJECT" --quiet

echo "Step 7f.5: Create a Load Balancing target HTTPS proxy"
gcloud compute target-https-proxies create apigee-proxy-https-proxy \
  --url-map apigee-proxy-map \
  --ssl-certificates apigee-ssl-cert --project "$PROJECT" --quiet

echo "Step 7f.6: Create a global forwarding rule"
gcloud compute forwarding-rules create apigee-proxy-https-lb-rule \
  --address lb-ipv4-vip-1 --global \
  --target-https-proxy apigee-proxy-https-proxy --ports 443 --project "$PROJECT" --quiet

set -e

echo ""
echo "Almost done. It take some time (another 5-8 minutes) to provision the load balancer infrastructure."
echo ""

# TODO: more intelligent wait until LB is ready

while true
do
  TLS_STATUS="$(gcloud compute ssl-certificates list --format=json  --project "$PROJECT" --quiet | jq -r '.[0].type')"
  if [ "$TLS_STATUS" = "MANAGED" ]; then
    TLS_STATUS="$TLS_STATUS ($(gcloud compute ssl-certificates list --format=json --project "$PROJECT" --quiet | jq -r '.[0].managed.status'))"
  fi
  DEPLOYMENT_STATUS="$(gcloud alpha apigee deployments describe 2>/dev/null --api hello-world --environment eval --format=json --project "$PROJECT" --quiet | jq -r '.state')"
  CURL_STATUS=$(curl -k -o /dev/null -s -w "%{http_code}\n" "https://$RUNTIME_HOST_ALIAS/hello-world" --resolve "$RUNTIME_HOST_ALIAS:443:$RUNTIME_IP" || true)
  echo "Test Curl Status: $CURL_STATUS, Deployment Status: $DEPLOYMENT_STATUS, Cert Status: $TLS_STATUS"
  if [ "$CURL_STATUS" = "200" ]; then
    break
  fi
  sleep 10
done

if [ "$CERTIFICATES" = "managed" ]; then
  echo "# To send an EXTERNAL test request, execute following command:"
  echo "curl https://$RUNTIME_HOST_ALIAS/hello-world -v"
else
  echo ""
  echo "# To send an INTERNAL test request (from a VM at the private network)"
  echo " copy $RUNTIME_TLS_CERT and execute following commands:"
  echo ""
  echo "export RUNTIME_IP=$APIGEE_ENDPOINT"

  echo "export RUNTIME_TLS_CERT=~/mig-cert.pem"
  echo "export RUNTIME_HOST_ALIAS=$RUNTIME_HOST_ALIAS"

  echo 'curl --cacert $RUNTIME_TLS_CERT https://$RUNTIME_HOST_ALIAS/hello-world -v --resolve "$RUNTIME_HOST_ALIAS:443:$RUNTIME_IP"'
  echo ""
  echo "You can also skip server certificate validation for testing purposes:"

  echo 'curl -k https://$RUNTIME_HOST_ALIAS/hello-world -v --resolve "$RUNTIME_HOST_ALIAS:443:$RUNTIME_IP"'
  echo ""

  echo ""
  echo "# To send an EXTERNAL test request, execute following commands:"
  echo ""
  echo "export RUNTIME_IP=$RUNTIME_IP"

  echo "export RUNTIME_TLS_CERT=~/mig-cert.pem"
  echo "export RUNTIME_HOST_ALIAS=$RUNTIME_HOST_ALIAS"

  echo 'curl --cacert $RUNTIME_TLS_CERT https://$RUNTIME_HOST_ALIAS/hello-world -v --resolve "$RUNTIME_HOST_ALIAS:443:$RUNTIME_IP"'
fi