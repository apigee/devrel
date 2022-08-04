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

gcloud --project=${PROJECT_ID} container clusters get-credentials \
${CLUSTER_NAME} --zone ${CLUSTER_LOCATION}

cat <<EOF >>apigee-ns.yaml 
apiVersion: v1
kind: Namespace
metadata:
  name: apigee
 
EOF

kubectl --context=${CLUSTER_CTX} apply -f apigee-ns.yaml 

kubectl --context=${CLUSTER_CTX} label namespace apigee istio-injection- istio.io/rev=asm-managed --overwrite

rm apigee-ns.yaml
