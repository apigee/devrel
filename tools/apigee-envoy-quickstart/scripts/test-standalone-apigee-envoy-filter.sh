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

testHttpbin() {
    printf "\nTesting deployed envoy proxy with apigee adapter\n"
    RESULT=1
    OUTPUT=$(curl -i http://localhost:8080/headers -H 'Host: httpbin.org' \
        -H "x-api-key: $CONSUMER_KEY" | grep HTTP)
    printf "\n$OUTPUT"
    if [[ "$OUTPUT" == *"200"* ]]; then
        RESULT=0
    fi
    return $RESULT
}

testCIRunnerHttpbin() {
    printf "\nTesting deployed envoy proxy with apigee adapter for CI runner build\n"
    envoyproxy_cntnr_name=$(docker ps -a --format "{{ json . }}" | \
                            jq ' select( .Image | contains("envoyproxy")) | .Names ' | \
                            tr -d '"')
    RESULT=1
    OUTPUT=$(docker exec -it $envoyproxy_cntnr_name curl -i http://localhost:8080/headers -H 'Host: httpbin.org' \
        -H "x-api-key: $CONSUMER_KEY" | grep HTTP)
    printf "\n$OUTPUT"
    if [[ "$OUTPUT" == *"200"* ]]; then
        RESULT=0
    fi
    return $RESULT
}

printf "\nExtract the consumer key\n"

export CONSUMER_KEY=$(curl -H "Authorization: ${TOKEN_TYPE} ${TOKEN}"  \
    -H "Content-Type:application/json" \
    "${MGMT_HOST}/v1/organizations/${APIGEE_ORG}/developers/test-envoy@google.com/apps/envoy-adapter-app-2" | \
    jq '.credentials[0].consumerKey'); \
    export CONSUMER_KEY=$(echo $CONSUMER_KEY|cut -d '"' -f 2); \
    echo "" && echo ""

printf "\nWait for few minutes for the Envoy and Apigee adapter to have the setup completed. Then try the below command"

printf "\n\n"

echo curl -i http://localhost:8080/headers -H "\"Host: httpbin.org\""  \
-H "\"x-api-key: $CONSUMER_KEY\""

printf "\n"

printf "\nTry with and without sending the x-api-key header. This proves the httpbin target is protected by the Envoy container which has the Envoy filter configured to connect to Apigee adapter running as container that executes the key verification with the Apigee runtime\n"


printf "\nWaiting for envoy proxy to be ready.."
sleep 20
printf "\nTesting envoy endpoint.."

if [[ -z $PIPELINE_TEST ]]; then
  testHttpbin;
else
  testCIRunnerHttpbin
fi
RESULT=$?

counter=0;
while [ $RESULT -ne 0 ] && [ $counter -lt 5 ]; do
  printf "\n\nTesting the httpbin application $counter of 5\n"
  sleep 20
  if [[ -z $PIPELINE_TEST ]]; then
    testHttpbin;
  else
    testCIRunnerHttpbin
  fi
  RESULT=$?
  counter=$((counter+1))
done

if [ $RESULT -eq 0 ]; then
  printf "\nValidation of the apigee envoy quickstart engine successful\n" 
else
  printf "\nValidation of the apigee envoy quickstart engine NOT successful\n" 
fi

