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
  printf "\n\nTesting the httpbin application\n"
  kubectl --context=${CLUSTER_CTX} -n $NAMESPACE run -it --rm --image=curlimages/curl --restart=Never curl \
      --overrides='{ "apiVersion": "v1", "metadata": {"annotations": { "sidecar.istio.io/inject":"false" } } }' \
      -- curl -i httpbin.apigee.svc.cluster.local/headers | grep 200 \
  2>&1 >/dev/null
  RESULT=$?
  return $RESULT
}

echo "Fixing the generated yaml files to use the namespace user provided"

kubectl --context=${CLUSTER_CTX} -n $NAMESPACE apply -f $CLI_HOME/config.yaml

cd $ENVOY_CONFIGS_HOME
sed -i "s/namespace: default/namespace: ${NAMESPACE}/g" $ENVOY_CONFIGS_HOME/httpbin.yaml
sed -i "s/namespace: default/namespace: ${NAMESPACE}/g" $ENVOY_CONFIGS_HOME/request-authentication.yaml
sed -i "s/namespace: default/namespace: ${NAMESPACE}/g" $ENVOY_CONFIGS_HOME/envoyfilter-sidecar.yaml

kubectl --context=${CLUSTER_CTX} -n $NAMESPACE apply -f httpbin.yaml
kubectl --context=${CLUSTER_CTX} -n $NAMESPACE apply -f apigee-envoy-adapter.yaml

#echo "Testing the sample application (httpbin) accessing via service endpoint."
#echo "Since the cluster is ASM enabled, all the requests targetted to service endpoints is prox'd thru Envoy sidecar proxy"
#echo "Without the Apigee Envoy service (Envoy Filter) is enabled, the requests to httpbin service is unprotected"

testHttpbin;
RESULT=$?

counter=0;
while [ $RESULT -ne 0 ] && [ $counter -lt 10 ]; do
  printf "\nTrying the httpbin to be ready $counter out of 10\n"
  testHttpbin;
  RESULT=$?
  sleep 5
  counter=$((counter+1))
done

if [ $RESULT -ne 0 ]; then
  printf "Access to httpbin ClusterIP endpoint fails after 5 tries, pre-enabling of envoy filter that enforces Apigee authentication this test should succeed"
  exit 1
fi


printf "Successfully tested the sample httpbin application"



