# Apigee hybrid 1.3 installation on GKE

The aim of this project is to facilitate a fully automated quickstart setup of Apigee hybrid on GKE. The configuration options are limited and simplified on purpose. The resulting Apigee hybrid environment is intended to serve as an initial end to end setup without production grade hardening and reliability.

For tooling related to production setup and operation of Apigee hybrid, please visit the [AHR project on Github](https://github.com/yuriylesyuk/ahr).

## Prerequisites

```bash
#installed kubectl
kubectl version

#installed gcloud
gcloud auth list

#login if needed
gcloud init
```

## Override Default Config (if desired)

```bash
export PROJECT_ID=xxx
export REGION='europe-west1'
export ZONE='europe-west1-b'
export DNS_NAME=apigee.example.com
export CLUSTER_NAME=apigee-hybrid
export ISTIO_ASM_CLI='istio-1.5.9-asm.0-osx.tar.gz' # linux: istio-1.5.9-asm.0-linux.tar.gz
export APIGEE_CTL_VERSION=1.3.2
export APIGEE_CTL='apigeectl_mac_64.tar.gz' # linux: apigeectl_linux_64.tar.gz
export KPT_VERSION='v0.33.0'
export KPT_BINARY='kpt_darwin_amd64_0.33.0.tar.gz' # kpt_linux_amd64_0.33.0.tar.gz
```

## Initialize GKE cluster

```bash
./initialize-gke.sh
```

## (Optional) Provision Trusted TLS/SSL Certificates
See the [this](https://community.apigee.com/articles/86322/free-trusted-ssl-certificates-for-apigee-hybrid-in.html) blog post in the Apigee community.

## Clean up

Delete the runtime resources to avoid paying for unused GKE clusters.

```bash
./cleanup.sh
```