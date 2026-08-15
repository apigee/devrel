# Apigee hybrid Quickstart Script

The aim of this project is to facilitate a fully automated quickstart setup of
Apigee hybrid on GKE. The configuration options are limited and simplified on
purpose. The resulting Apigee hybrid environment is intended to serve as an
initial end to end setup without production grade hardening and reliability.

For tooling related to production setup and operation of Apigee hybrid, please
visit the [AHR project on Github](https://github.com/apigee/ahr).

This script is tested on MacOS and Linux with the prerequisites in the next
section installed. It can also be run in Cloud Shell. In case your cloud shell
times out just run it again.

[![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.svg)](https://ssh.cloud.google.com/cloudshell/editor?cloudshell_git_repo=https://github.com/apigee/devrel&cloudshell_workspace=tools/hybrid-quickstart&cloudshell_tutorial=README.md)

## Prerequisites

In order to run the script you will need a few basic utilities and an
initialized gcloud context:

```bash
#installed kubectl
kubectl version

#installed helm 3.10.0+ (b/288407289#comment18)
helm version

#installed tar
tar --version

#installed openssl
openssl version

#installed gcloud
gcloud version

#installed zip
zip -v

#installed timeout
timeout --version

#login if needed
gcloud auth list
```

## Select a GCP project

Select the GCP project to install hybrid:

```sh
export PROJECT_ID=xxx
```

or create a new project:

```sh
gcloud projects create PROJECT_NAME [OPTIONS]
export PROJECT_ID=PROJECT_NAME
```

## Override Default Config (if desired)

The following environment variables are set by default.
Export them to override the default values if needed.

### Apigee analytics region see Apigee docs for full list

```sh
export AX_REGION='europe-west1'
```

### GCP region and zone for the runtime

```sh
export REGION='europe-west1'
export ZONE='europe-west1-b,europe-west1-c,europe-west1-d'
```

### Networking

```sh
export NETWORK='apigee-hybrid'
export SUBNET='apigee-europe-west1'
```

### Runtime GKE cluster

```sh
export GKE_CLUSTER_NAME='apigee-hybrid'
export GKE_CLUSTER_MACHINE_TYPE='e2-standard-4'
```

### Apigee Env Config

```sh
export ENV_NAME='test1'
export ENV_GROUP_NAME='test'
```

### Ingress config

By default a subdomain will be created for every environment group
e.g. test.1-2-3-4.nip.io (where 1.2.3.4 is the IP of the istio ingress)

`INGRESS_TYPE` can be `external` (default) ~~or `internal`~~
(A known issue that prevents the creation of internal LBs at the moment.)

```sh
export DNS_NAME="my-ingress-ip.nip.io"
# Choose between 'external' and 'internal' ingress
export INGRESS_TYPE="external"
```

**Note:** If the custom `DNS_NAME` you would like to use has been used with
CloudDNS before, you need to prove your ownership over that domain. For this
you have to create a DNS zone called `apigee-dns-zone` and your env group A
records. The quickstart checks if the `apigee-dns-zone` already exists and will
skip its creation.
If you use the default `DNS_NAME` you don't have to manually create a dns zone.

## TLS/SSL Certificates

You can use one of three different ways to issue TLS certificates for your
Apigee hybrid ingress:

- `export CERT_TYPE='google-managed'` (default) Use a Google-managed certificate.
  For details see [this](https://www.googlecloudcommunity.com/gc/Cloud-Product-Articles/Apigee-hybrid-ingress-Three-different-options-to-expose-your/ta-p/79149)
  blog post in the Apigee community. This requires external ingress.
- `export CERT_TYPE='self-signed'` creates self-signed certificates
- `export CERT_TYPE='skip'` skips the certificate creation and relies on you
  creating a `tls-hybrid-ingress` certificate in the `istio-system` namespace.

## Initialize the Apigee hybrid runtime on a GKE cluster

After the configuration is done run the following command to initialize you
Apigee hybrid organization and runtime. This typically takes between 15 and
20min.

```sh
./initialize-runtime-gke.sh
```

## Clean up

This tool includes a script to automatically clean up the Apigee hybrid
runtime resources (without deleting the Apigee Organization).

**Note:** The cleanup script is designed to run on a standalone GCP project.
If you provisioned the quickstart in a GCP project with other resources
consider deleting the GCP resources manually to avoid accidentally deleting
the resources that are needed by other services.

```sh
./destroy-runtime-gke.sh
```
