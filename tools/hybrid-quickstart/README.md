# Apigee hybrid Quickstart Script

The aim of this project is to facilitate a fully automated quickstart setup of
Apigee hybrid on GKE. The configuration options are limited and simplified on
purpose. The resulting Apigee hybrid environment is intended to serve as an
initial end to end setup without production grade hardening and reliability.

For tooling related to production setup and operation of Apigee hybrid, please
visit the [AHR project on Github](https://github.com/apigee/ahr).

## Prerequisites

```bash
#installed kubectl
kubectl version

#installed tar
tar --version

#installed openssl
openssl version

#installed gcloud
gcloud version

#login if needed
gcloud init
```

## Override Default Config (if desired)

The following environment variables are set by default.
Export them to override the default values if neeed.

```bash
export PROJECT_ID=xxx
# Apigee analytics region see Apigee docs for full list
export AX_REGION='europe-west1'
# Default GCP region for runtime
export REGION='europe-west1'
export ZONE='europe-west1-c'
# Name of the GKE cluster that hosts the runtime
export GKE_CLUSTER_NAME='apigee-hybrid'
# Machine type of the GKE cluster that hosts the runtime
export GKE_CLUSTER_MACHINE_TYPE='e2-standard-4'
# Apigee Config
export ENV_NAME='test1'
export ENV_GROUP_NAME='test'
# Subdomain will be created for every environment group
# e.g. test.$PROJECT_ID.example.com
export DNS_NAME="$PROJECT_ID.example.com"
# Choose between 'external' and 'internal' ingress
export INGRESS_TYPE="external"
```

**Note:** If the custom `DNS_NAME` you would like to use has been used with
CloudDNS before, you need to prove your ownership over that domain. For this
you have to create a DNS zone called `apigee-dns-zone` and your env group A
records. The quickstart checks if the `apigee-dns-zone` already exists and will
skip its creation.
If you use the default `DNS_NAME` you don't have to manually create a dns zone.

## Initialize the Apigee hybrid runtime on a GKE cluster

```bash
./initialize-runtime-gke.sh
```

## (Optional) Provision Trusted TLS/SSL Certificates

See the [this](https://community.apigee.com/articles/86322/free-trusted-ssl-certificates-for-apigee-hybrid-in.html)
 blog post in the Apigee community.

## Clean up

Delete the runtime resources to avoid paying for unused GKE clusters.

```bash
./destroy-runtime-gke.sh
```
