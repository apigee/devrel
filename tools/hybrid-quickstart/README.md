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

#installed tar
tar --version

#installed openssl
openssl version

#installed gcloud
gcloud version

#installed zip
zip -v

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
export ZONE='europe-west1-c'
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
e.g. test.1-2-3-4.nip.io (where 1.2.3.4 is the IP of the isto ingress)

`INGRESS_TYPE` can be `external` (default) or `internal`

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

## Initialize the Apigee hybrid runtime on a GKE cluster

After the configuration is done run the following command to initialize you
Apigee hybrid organization and runtime. This typically takes between 15 and
20min.

```sh
./initialize-runtime-gke.sh
```

## (Optional) Provision Trusted TLS/SSL Certificates

See the [this](https://community.apigee.com/articles/86322/free-trusted-ssl-certificates-for-apigee-hybrid-in.html)
 blog post in the Apigee community.

## Clean up

Delete the runtime resources (without deleting the Apigee Organization) to avoid
paying for unused GKE clusters.

```sh
./destroy-runtime-gke.sh
```
