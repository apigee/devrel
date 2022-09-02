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

delete_sa_keys() {
  for SA_KEY_NAME in $(gcloud iam service-accounts keys list \
  --project="$APIGEE_PROJECT_ID" \
  --iam-account="$ENVOY_AX_SA"@"$APIGEE_PROJECT_ID".iam.gserviceaccount.com \
  --format="get(name)" --filter="keyType=USER_MANAGED")
  do
    gcloud iam service-accounts keys delete "$SA_KEY_NAME" \
    --project="$APIGEE_PROJECT_ID" \
    --iam-account="$ENVOY_AX_SA"@"$APIGEE_PROJECT_ID".iam.gserviceaccount.com -q
  done
}

if [ "$INSTALL_TYPE" == 'istio-apigee-envoy' ]
then
    gcloud --project="${PROJECT_ID}" container clusters get-credentials \
    "${CLUSTER_NAME}" --zone "${CLUSTER_LOCATION}"

    echo "Deleting the namespace - $NAMESPACE"
    kubectl --context="${CLUSTER_CTX}" delete namespace "$NAMESPACE"
fi

if [ "$PLATFORM" != 'opdk' ] && [ "$PLATFORM" != 'edge' ]
then
    echo "deleting the SA keys"
    delete_sa_keys;

    if [[ -z $PIPELINE_TEST ]]; then

        echo "Deleting the service account role binding"
        gcloud projects remove-iam-policy-binding "$APIGEE_PROJECT_ID" \
        --member="serviceAccount:$ENVOY_AX_SA@$APIGEE_PROJECT_ID.iam.gserviceaccount.com" \
        --role="roles/apigee.analyticsAgent"

        echo "Deleting the service account"
        gcloud iam service-accounts delete "$ENVOY_AX_SA"@"$APIGEE_PROJECT_ID".iam.gserviceaccount.com \
        --project="$APIGEE_PROJECT_ID" --quiet
    fi
    rm "$AX_SERVICE_ACCOUNT"
fi

if [ "$INSTALL_TYPE" == 'standalone-apigee-envoy' ]
then
    echo "Deleting docker containers"
    docker ps -a --format "{{ json . }}" | jq ' select( .Image | contains("envoyproxy")) | .Names ' | xargs docker rm -f
    docker ps -a --format "{{ json . }}" | jq ' select( .Image | contains("apigee-envoy-adapter")) | .Names ' | xargs docker rm -f
fi

echo "Deleting the developer app"
curl -H "Authorization: ${TOKEN_TYPE} ${TOKEN}" -X DELETE "${MGMT_HOST}/v1/organizations/${APIGEE_ORG}/developers/test-envoy@google.com/apps/envoy-adapter-dev-app"

echo "Deleting the developer"
curl -H "Authorization: ${TOKEN_TYPE} ${TOKEN}" -X DELETE "${MGMT_HOST}/v1/organizations/${APIGEE_ORG}/developers/test-envoy@google.com"

echo "Deleting the product"
curl -H "Authorization: ${TOKEN_TYPE} ${TOKEN}" -X DELETE "${MGMT_HOST}/v1/organizations/${APIGEE_ORG}/apiproducts/envoy-adapter-product-2"


echo "Deleting the directory"
rm -Rf "$CLI_HOME"
rm -Rf "$REMOTE_SERVICE_HOME"
rm "$ENVOY_HOME"/*.tar.*

echo "Done with the cleanup.."

