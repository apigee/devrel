#!/bin/bash

# Copyright 2022 Google LLC
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

set -e

init() {
  export CLUSTER_CTX="gke_${PROJECT_ID}_${CLUSTER_LOCATION}_${CLUSTER_NAME}"
  export ASM_GATEWAYS_NAMESPACE="istio-ingressgateway"
  export USE_GKE_GCLOUD_AUTH_PLUGIN=True
  export MGMT_HOST="https://apigee.googleapis.com"
  export APIGEE_ORG=$APIGEE_PROJECT_ID
  gcloud container clusters get-credentials "$CLUSTER_NAME" \
     --zone "$CLUSTER_LOCATION" \
     --project "$PROJECT_ID"

}

validate() {
    if [[ -z $PROJECT_ID ]]; then
        echo "Environment variable PROJECT_ID is not set, please checkout README.md"
        exit 1
    fi

    if [[ -z $CLUSTER_NAME ]]; then
        echo "Environment variable CLUSTER_NAME is not set, please checkout README.md"
        exit 1
    fi

    if [[ -z $CLUSTER_LOCATION ]]; then
        echo "Environment variable CLUSTER_LOCATION is not set, please checkout README.md"
        exit 1
    fi

    if [[ -z $ENVOY_HOME ]]; then
        echo "Environment variable ENVOY_HOME is not set, please set this to the location where devrel is downloads, please checkout README.md for more details"
        exit 1
    fi

    if [[ -z $TOKEN ]]; then
        echo "Environment variable TOKEN is not set, please checkout README.md"
        exit 1
    fi

    if [[ -z $APIGEE_PROJECT_ID ]]; then
        echo "Environment variable $APIGEE_PROJECT_ID is not set, please checkout README.md"
        exit 1
    fi
}

getIngressGatewayExternalIP() {
  EXTERNAL_IP=$(kubectl --context="${CLUSTER_CTX}" get svc -n "$ASM_GATEWAYS_NAMESPACE" -o json | \
  jq '.items[0].status.loadBalancer.ingress[0].ip' | \
  cut -d '"' -f 2)
  export EXTERNAL_IP;
}

installIstioIngressGateway() {

  git clone https://github.com/GoogleCloudPlatform/anthos-service-mesh-packages.git \
  "$ENVOY_HOME"/asm

  kubectl create namespace $ASM_GATEWAYS_NAMESPACE

  kubectl label namespace $ASM_GATEWAYS_NAMESPACE istio-injection=enabled istio.io/rev-

  kubectl apply -n $ASM_GATEWAYS_NAMESPACE \
    -f "$ENVOY_HOME"/asm/samples/gateways/istio-ingressgateway

  kubectl rollout restart deployment -n $ASM_GATEWAYS_NAMESPACE

  getIngressGatewayExternalIP;

  counter=0;
  while [[ "$EXTERNAL_IP" == 'null' ]] && [[ $counter -lt 10 ]]; do
    printf "\n\nTesting the availability of EXTERNAL_IP for ingressgateway,  %s of 10\n" "$counter"
    sleep 5
    getIngressGatewayExternalIP;
    counter=$((counter+1))
  done

}

fetchConsumerKey() {
  CONSUMER_KEY=$(curl -H "Authorization: Bearer ${TOKEN}"  \
    -H "Content-Type:application/json" \
    "${MGMT_HOST}/v1/organizations/${APIGEE_ORG}/developers/test-envoy@google.com/apps/envoy-adapter-app-2" | \
    jq '.credentials[0].consumerKey'); \
    CONSUMER_KEY=$(echo "$CONSUMER_KEY"|cut -d '"' -f 2); export CONSUMER_KEY; \
    printf "\n" && printf "\n"

  if [[ -z "$CONSUMER_KEY" ]] || [[ "$CONSUMER_KEY" == 'null' ]]; then
      echo "Failed in extracting the CONSUMER_KEY of the developer app attached to the httpbin product in Apigee org"
      exit 1
  fi
}

testExternalAccess() {
  RESULT=1
  OUTPUT=$(curl -i http://"$EXTERNAL_IP"/headers -H 'Host: httpbin.org' \
      -H "x-api-key: $CONSUMER_KEY" | grep HTTP)

  printf "\n%s" "$OUTPUT"
  if [[ "$OUTPUT" == *"200"* ]]; then
      RESULT=0
  fi
  return $RESULT
}

echo 'Initializing...'
init;

echo 'Validating...'
validate;

ISTO_INGRESSGATEWAY_CNT=$(kubectl --context="${CLUSTER_CTX}" get svc -n "$ASM_GATEWAYS_NAMESPACE" -o json | \
jq '.items|length')

if [ "$ISTO_INGRESSGATEWAY_CNT" == 0 ]; then
  echo "No istio ingressgateway found, installing..."
  installIstioIngressGateway;
fi

echo "Getting ingressgateway external ipaddress..."
getIngressGatewayExternalIP;

if [[ -z "$EXTERNAL_IP" ]] || [[ "$EXTERNAL_IP" == 'null' ]]; then
    echo "ExternalIP is not set on the istio ingressgateway, exiting"
    exit 1
fi

echo "Installing gateway for httpbin..."
cat <<EOF > "${ENVOY_HOME}"/httpbin-gateway.yaml
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
 name: httpbin-gateway
spec:
 selector:
   istio: ingressgateway
 servers:
   - port:
       number: 80
       name: http
       protocol: HTTP
     hosts:
       - "httpbin.org"
EOF

kubectl apply -n $ASM_GATEWAYS_NAMESPACE \
  -f "$ENVOY_HOME"/httpbin-gateway.yaml

echo "Installing virtualservice for httpbin..."
cat <<EOF > "${ENVOY_HOME}"/httpbin-virtual-service.yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: httpbin-ingress
spec:
  hosts:
  - "httpbin.org"
  gateways:
  - httpbin-gateway
  http:
  - route:
    - destination:
        host: httpbin.apigee.svc.cluster.local
        port:
          number: 80
EOF

kubectl apply -n $ASM_GATEWAYS_NAMESPACE \
  -f "$ENVOY_HOME"/httpbin-virtual-service.yaml

fetchConsumerKey;

echo "Testing httpbin via external IP..."
echo curl -i http://"$EXTERNAL_IP"/headers -H "\"x-api-key: $CONSUMER_KEY\"" -H "\"Host: httpbin.org\""
echo "Waiting for the deployments to be complete (35s)..."

sleep 35;
testExternalAccess;
RESULT=$?

counter=0;
while [ $RESULT -ne 0 ] && [ $counter -lt 5 ]; do
  printf "\n\nTesting the httpbin application via external access %s of 5\n" "$counter"
  sleep 5
  testExternalAccess;
  RESULT=$?
  counter=$((counter+1))
done

if [[ $counter != 5 ]]; then
  printf "\n"
  echo "SUCCESS: use the above curl command to validate external access of deployed httpbin service protected by envoy-apigee integration"
  printf "\n"
fi

echo "Note: The reason for host override is bcos of the Apigee product is protecting this api host. \
The request hitting the Loadbalancer (via istio-ingressgateway) can carry any valid domain name resolving to the LB. \
The apigee product protects the k8s ClusterIP service host and hence needed the Host override in the request. 
Only for this service host the envoy apigee adapter will trigger the authn with Apigee runtime."
printf "\n"
echo "If a domain name is alias'd to the LB and the request should be protected via Envoy, this domain name should be added to the Apigee product."

printf "\n\n"

