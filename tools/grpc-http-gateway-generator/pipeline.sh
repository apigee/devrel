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

GCP_REGION=europe-west2

# Run a currency mock service
docker run --name grpc-mock --detach \
  -p 9090:9090 -e PORT=9090 \
  -e DISABLE_PROFILER=1 -e DISABLE_DEBUGGER=1 \
  gcr.io/google-samples/microservices-demo/currencyservice:v0.10.0 &> /dev/null

# Trap for cleanup
trap 'docker kill grpc-mock || true; docker rm grpc-mock || true' EXIT INT TERM

# Generate the gRCP Gateway based on the proto file
rm -rdf generated || true
./generate-gateway.sh --proto-path ./examples/currency.proto

# Build and run the gRPC Gateway
(cd generated/gateway && CGO_ENABLED=0 go build -o grpcgateway .)
./generated/gateway/grpcgateway --grpc-server-endpoint localhost:9090 &
GATEWAY_PID=$!

# Extended trap for cleanup
trap 'docker kill grpc-mock &> /dev/null || true; docker rm grpc-mock &> /dev/null || true; kill $GATEWAY_PID || true' EXIT INT TERM

# Smoke test the gRPC Gateway
# curl --fail -X POST localhost:8080/hipstershop.CurrencyService/Convert \
# -d '{"from": {"units": 3, "currency_code": "USD", "nanos": 0}, "to_code": "CHF"}'

# curl --fail -X POST localhost:8080/hipstershop.CurrencyService/GetSupportedCurrencies

# Build the grpc-gateway container and push it to Artifact Registry
(cd generated/gateway && docker build -t grpc-gateway:latest .)

DOCKER_REPO="docker"
if [ -z "$(gcloud artifacts repositories describe $DOCKER_REPO --location=$GCP_REGION --format='get(name)')" ]; then \
  gcloud artifacts repositories create $DOCKER_REPO \
      --repository-format=docker \
      --location=$GCP_REGION \
      --project=$APIGEE_X_ORG
fi

IMAGE_PATH="$GCP_REGION-docker.pkg.dev/$APIGEE_X_ORG/$DOCKER_REPO/grpc-gateway"
docker tag grpc-gateway:latest "$IMAGE_PATH:latest"
docker push "$IMAGE_PATH"

sed -i.bak "s|GRPC_GATEWAY_IMAGE|$IMAGE_PATH|g" "templates/cloud-run-service.yaml"

gcloud run services replace templates/cloud-run-service.yaml \
  --project $APIGEE_X_ORG --region $GCP_REGION \
  --platform managed

# Generate and deploy an Apigee API proxy for the currency-service
SA_EMAIL="apigee-runtime@$APIGEE_X_ORG.iam.gserviceaccount.com"

if [ -z "$(gcloud iam service-accounts list --filter "$SA_EMAIL" --format="value(email)"  --project "$APIGEE_X_ORG")" ]; then
    gcloud iam service-accounts create apigee-runtime \
        --description="Apigee Runtime" --project "$APIGEE_X_ORG"
fi

gcloud run services add-iam-policy-binding currency-service \
	 --member="serviceAccount:$SA_EMAIL" \
	 --role='roles/run.invoker' \
	 --region=$GCP_REGION \
	 --platform=managed --project "$APIGEE_X_ORG"

CLOUD_RUN_URL=$(gcloud run services list --filter currency-service --format="value(status.url)" --limit 1)
sed -i "s|CLOUD_RUN_URL|$CLOUD_RUN_URL|g" "templates/apiproxy/targets/default.xml"

TOKEN="$(gcloud config config-helper --force-auth-refresh --format json | jq -r '.credential.access_token')"
sackmesser deploy -d "$SCRIPTPATH/templates" -o "$APIGEE_X_ORG" -e "$APIGEE_X_ENV" -t "$TOKEN" --deployment-sa "$SA_EMAIL"

# Test the Apigee API
curl -X GET "https://$APIGEE_X_HOSTNAME/currency/v1/currencies"

curl -X POST "https://$APIGEE_X_HOSTNAME/currency/v1/convert" \
   -d '{"from": {"units": 3, "currency_code": "USD", "nanos": 0}, "to_code": "CHF"}'

# Clean up
  # undeploy and delete proxy
  # delete CR service
  # delete SA
  # delete AR registry
