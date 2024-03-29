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

testHttpbin() {
  RESULT=1

  kubectl --context="${CLUSTER_CTX}" -n "$NAMESPACE" run -it --rm --image=curlimages/curl \
  --restart=Never curl --overrides='{"apiVersion": "v1", "metadata": {"annotations":{"sidecar.istio.io/inject": "false"}}}' \
  -- curl -i httpbin.apigee.svc.cluster.local/headers -H "x-api-key: $CONSUMER_KEY" > "$ENVOY_HOME"/test-curl-output.txt
  
  OUTPUT=$( grep "HTTP" "$ENVOY_HOME"/test-curl-output.txt)
  rm "$ENVOY_HOME"/test-curl-output.txt

  if [[ "$OUTPUT" == *"200"* ]]; then
      RESULT=0
  fi
  return $RESULT
}

printf "\nExtract the consumer key"

CONSUMER_KEY=$(curl -H "Authorization: ${TOKEN_TYPE} ${TOKEN}"  \
    -H "Content-Type:application/json" \
    "${MGMT_HOST}/v1/organizations/${APIGEE_ORG}/developers/test-envoy@google.com/apps/envoy-adapter-dev-app" | \
    jq '.credentials[0].consumerKey'); \
    CONSUMER_KEY=$(echo "$CONSUMER_KEY"|cut -d '"' -f 2); export CONSUMER_KEY; \
    printf "\n" && printf "\n"

printf "\nWait for few minutes for the Envoy and Apigee adapter to have the setup completed. Then try the below command"

printf "\n\n"

printf "kubectl --context=\"%s\" -n \"%s\" run -it --rm --image=curlimages/curl --restart=Never curl \
--overrides=\'{\"apiVersion\":\"v1\", \"metadata\":{\"annotations\": { \"sidecar.istio.io/inject\":\"false\" } } }\' \
-- curl -i httpbin.apigee.svc.cluster.local/headers -H \'x-api-key: %s\'" "${CLUSTER_CTX}" "${NAMESPACE}" "${CONSUMER_KEY}"

printf "\n"

printf "\nTry with and without sending the x-api-key header: this proves the httpbin service is intercepted by the Envoy sidecar which has the Envoy filter configured to connect to Apigee adapter running as container that executes the key verification with the Apigee runtime"

printf "\n"

testHttpbin;
RESULT=$?

counter=0;
while [[ $RESULT -ne 0 ]] && [[ $counter -lt 5 ]]; do
  printf "\n\nTesting the httpbin application %s of 5\n" "$counter"
  sleep 20
  testHttpbin;
  RESULT=$?
  counter=$((counter+1))
done

if [ $RESULT -eq 0 ]; then
  printf '\U1F44D'
  printf "\nValidation of the apigee envoy quickstart engine successful\n\n" 
else
  printf "\n\nValidation of the apigee envoy quickstart engine NOT successful\n\n" 
fi
