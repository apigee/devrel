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


set -e

# check if protoc is installed
if ! command -v protoc &> /dev/null; then
  echo "[ERROR] protoc is not installed. Please install protoc before running this script."
  exit 1
fi

proto_path=""
out=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --proto-path)
      proto_path="$2"
      shift 2
      ;;
    --out)
      out="$2"
      shift 2
      ;;
    --*|-*)
      echo "Unknown option $1"
      exit 1
      ;;
  esac
done

# check if proto path is provided
if [ -z "$proto_path" ]; then
  echo "[ERROR] Proto path is required supply via variable --proto-path"
  exit 1
fi

# check if proto path is a file 
if [ ! -f "$proto_path" ]; then
  echo "[ERROR] Proto path is not a file"
  exit 1
fi

# check if output directory is provided
if [ -z "$out" ]; then
  echo "[WARN] Output directory is not provided via variable --out. Using the default value ./generated/gateway"
  out="$(pwd)/generated/gateway"
else
  mkdir -p "$out"
  out="$(cd "$out"; pwd -P)"
fi

script_dir="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

temp_dir=$(mktemp -d)
proto_file_name=$(basename "$proto_path")
cp "$proto_path" "$temp_dir/$proto_file_name"


# install tooling dependencies
pushd "$script_dir/tools" &> /dev/null
go mod tidy
go install \
    github.com/grpc-ecosystem/grpc-gateway/v2/protoc-gen-grpc-gateway \
    github.com/grpc-ecosystem/grpc-gateway/v2/protoc-gen-openapiv2 \
    google.golang.org/protobuf/cmd/protoc-gen-go \
    google.golang.org/grpc/cmd/protoc-gen-go-grpc
PATH="$PATH:$(go env GOPATH)/bin"
export PATH
popd &> /dev/null

# Generate the gRPC adapter
mkdir -p "$out/adapter"

pushd "$temp_dir" &> /dev/null
protoc -I . \
  --go_out "$out/adapter" \
  --go_opt "M$proto_file_name=.;adapter" \
  --go-grpc_out "$out/adapter" \
  --go-grpc_opt "M$proto_file_name=.;adapter" \
  "./$proto_file_name"

protoc -I . --grpc-gateway_out "$out/adapter" \
  --grpc-gateway_opt "M$proto_file_name=.;adapter" \
  --grpc-gateway_opt generate_unbound_methods=true \
  "./$proto_file_name"
popd &> /dev/null

cp "$script_dir/templates/main.go" "$out/main.go"
cp "$script_dir/templates/Dockerfile" "$out/Dockerfile"

(cd "$out/adapter" && go mod init adapter &> /dev/null && go mod tidy &> /dev/null)
(cd "$out" && go mod init gateway &> /dev/null && go mod edit -replace adapter=./adapter && go mod tidy &> /dev/null)
