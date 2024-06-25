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