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

# Run a currency mock service
docker run --name grpc-mock --detach \
  -p 9090:9090 -e PORT=9090 gcr.io/google-samples/microservices-demo/currencyservice:v0.10.0 

# Trap for cleanup
trap 'docker kill grpc-mock || true; docker rm grpc-mock || true' EXIT INT TERM

# Generate the gRCP Gateway based on the proto file
rm -rdf generated || true
./generate-gateway.sh --proto-path ./examples/currency.proto

# Build and run the gRPC Gateway
(cd generated/gateway && CGO_ENABLED=0 go build -o grpcgateway .)
./generated/gateway/grpcgateway --grpc-server-endpoint localhost:9090 &
GATEWAY_PID=$!
echo "$GATEWAY_PID"

# Extended trap for cleanup
trap 'docker kill grpc-mock || true; docker rm grpc-mock || true; kill $GATEWAY_PID || true' EXIT INT TERM

# Smoke test the gRPC Gateway
curl -X POST localhost:8080/hipstershop.CurrencyService/Convert \
-d '{"from": {"units": 3, "currency_code": "USD", "nanos": 0}, "to_code": "CHF"}'
