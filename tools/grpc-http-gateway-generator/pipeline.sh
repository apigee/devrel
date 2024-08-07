#!/bin/bash

# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e # exit on first error

SCRIPTPATH="$( cd "$(dirname "$0")" || exit >/dev/null 2>&1 ; pwd -P )"
export PATH="$PATH:$SCRIPTPATH/../../tools/apigee-sackmesser/bin"

PROJECT_ID=$(gcloud config get-value project)
GCP_REGION=europe-west2

# Generate the gRCP Gateway based on the proto file
rm -rdf generated || true
./generate-gateway.sh --proto-path ./examples/currency.proto

# Build the gRPC Gateway
(cd generated/gateway && CGO_ENABLED=0 go build -o grpcgateway .)

# Build the grpc-gateway container and push it to Artifact Registry
(cd generated/gateway && docker build -t grpc-gateway:latest .)

DOCKER_REPO="devrel"
REPO_LOCATION="europe"

if [ -z "$(gcloud artifacts repositories describe $DOCKER_REPO \
   --location=$REPO_LOCATION \
   --project "$PROJECT_ID" \
   --format='get(name)')" ]; then \
  
  gcloud artifacts repositories create $DOCKER_REPO \
      --repository-format=docker \
      --location=$REPO_LOCATION \
      --project="$PROJECT_ID"
fi

IMAGE_PATH="$REPO_LOCATION-docker.pkg.dev/$PROJECT_ID/$DOCKER_REPO/grpc-gateway"
docker tag grpc-gateway:latest "$IMAGE_PATH:latest"
docker push "$IMAGE_PATH"

# Deploy grpc-gateway container to Cloud Run
sed -i.bak "s|GRPC_GATEWAY_IMAGE|$IMAGE_PATH|g" "examples/currency-v1/cloud-run-service.yaml"

gcloud run services replace examples/currency-v1/cloud-run-service.yaml \
  --project "$PROJECT_ID" --region $GCP_REGION \
  --platform managed

# Generate and deploy an Apigee API proxy for the currency-service
SA_EMAIL="apigee-test-cloudrun@$APIGEE_X_ORG.iam.gserviceaccount.com"

if [ -z "$(gcloud iam service-accounts list --filter "$SA_EMAIL" --format="value(email)"  --project "$APIGEE_X_ORG")" ]; then
    gcloud iam service-accounts create apigee-test-cloudrun \
        --description="Apigee Test Cloud Run" --project "$APIGEE_X_ORG"
fi

gcloud run services add-iam-policy-binding currency-service \
	 --member="serviceAccount:$SA_EMAIL" \
	 --role='roles/run.invoker' \
	 --region=$GCP_REGION \
	 --platform=managed --project "$PROJECT_ID"

CLOUD_RUN_URL=$(gcloud run services list --filter currency-service --format="value(status.url)" --limit 1)
sed -i "s|CLOUD_RUN_URL|$CLOUD_RUN_URL|g" "examples/currency-v1/apiproxy/targets/default.xml"

TOKEN="$(gcloud config config-helper --force-auth-refresh --format json | jq -r '.credential.access_token')"
sackmesser deploy -d "$SCRIPTPATH/examples/currency-v1" -o "$APIGEE_X_ORG" -e "$APIGEE_X_ENV" -t "$TOKEN" --deployment-sa "$SA_EMAIL"

# Test the Apigee API
curl -X GET "https://$APIGEE_X_HOSTNAME/currency/v1/currencies"

curl -X POST "https://$APIGEE_X_HOSTNAME/currency/v1/convert" \
   -d '{"from": {"units": 3, "currency_code": "USD", "nanos": 0}, "to_code": "CHF"}'

# Clean up
  # undeploy and delete proxy
  # delete CR service
  # delete SA
  # delete AR registry
