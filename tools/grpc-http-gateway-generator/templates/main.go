// Copyright 2024 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package main

import (
  "context"
  "flag"
  "net/http"
  "os"

  "github.com/grpc-ecosystem/grpc-gateway/v2/runtime"
  "google.golang.org/grpc"
  "google.golang.org/grpc/credentials/insecure"
  "google.golang.org/grpc/grpclog"

  gw "adapter" // needs to be replaced
)

var (
  // command-line options:
  // gRPC server endpoint
  grpcServerEndpointFlag = flag.String("grpc-server-endpoint",  "", "gRPC server endpoint")
)

func run() error {
  ctx := context.Background()
  ctx, cancel := context.WithCancel(ctx)
  defer cancel()

  // Register gRPC server endpoint
  mux := runtime.NewServeMux()
  opts := []grpc.DialOption{grpc.WithTransportCredentials(insecure.NewCredentials())}

  grpcServerEndpoint := *grpcServerEndpointFlag
  if grpcServerEndpoint == "" {
    grpcServerEndpoint = os.Getenv("GRPC_SERVER_ENDPOINT")
  }
  if grpcServerEndpoint == "" {
    grpcServerEndpoint = "localhost:9090"
  }

  grpclog.Infof("Upstream gRPC server endpoint = %s", grpcServerEndpoint)

  err := gw.RegisterCurrencyServiceHandlerFromEndpoint(ctx, mux, grpcServerEndpoint, opts)
  if err != nil {
    return err
  }

  // Start HTTP server (and proxy calls to gRPC server endpoint)
  port := os.Getenv("PORT")
  if port == "" {
    port = "8080"
  }
  grpclog.Infof("Serving gRPC-Gateway on http://0.0.0.0:%s", port)
  return http.ListenAndServe( ":" + port, mux)
}

func main() {
  flag.Parse()

  if err := run(); err != nil {
    grpclog.Fatal(err)
  }
}