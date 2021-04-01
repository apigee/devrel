# Apigee X Trial Provisioning

> Note - this script is not subject to pipelines

## Description

This script creates an Apigee X evaluation organization and instance. It uses
`gcloud` commands to create an Apigee runtime instance,
a proxy [MIG](https://cloud.google.com/compute/docs/instance-groups) and a
[GCLB](https://cloud.google.com/load-balancing/docs) for external exposure.

The script follows the documentation installation steps. The relevant step
numbers are added for easier cross-referencing.

If you provisioned an organization using the [Apigee eval provisioning wizard](https://cloud.google.com/apigee/docs/api-platform/get-started/eval-orgs#wiz),
you can run this script to add the proxy MIG and GCLB configuration for
external exposure.

A reference example of [Command Line](https://cloud.google.com/apigee/docs/api-platform/get-started/install-cli)
Provisioning for Apigee X.

Please refer to the documentation for the latest usage.

## Usage

**Note:** To customize your installation with optional configuration parameters
see below.

You need to set up a `PROJECT` environment variable.

```sh
export PROJECT=<gcp-project-name>
```

Then you can run the script. You can use the `--quiet` option to skip the manual
confirmation step.

```sh
 ./apigee-x-trial-provision.sh
```

To invoke the script directly from the github repo, use

```sh
<!-- markdownlint-disable-next-line MD013 -->
curl -L https://raw.githubusercontent.com/apigee/devrel/main/tools/apigee-x-trial-provision/apigee-x-trial-provision.sh | bash -
```

WARNING: A successful `Provisioning organization...` step takes 25-30 minutes
to complete. According to the documentation: "This is a long running operation
and could take anywhere from 10 minutes to 1 hour to complete." [->](https://cloud.google.com/sdk/gcloud/reference/alpha/apigee/organizations/provision)

After the script runs, it displays your `RUNTIME_IP`, `RUNTIME_SSL_CERT`
location, your `RUNTIME_HOST_ALIAS`, and an example `curl` command to send a test
request to an automatically deployed hello-world proxy.

When the script finishes, it takes an extra 5-7 minutes to provision
the load balancing infrastructure. You can use the example `curl` command
to run it until 200 OK is returned to ensure that Apigee X install
is fully completed.

Sample Output (using the self-signed certificate option, see below):

```sh
export RUNTIME_IP=203.0.113.10

export RUNTIME_SSL_CERT=~/mig-cert.pem
export RUNTIME_HOST_ALIAS=$PROJECT-eval.apigee.net

curl --cacert $RUNTIME_SSL_CERT https://$RUNTIME_HOST_ALIAS/hello-world -v \
  --resolve "$RUNTIME_HOST_ALIAS:443:$RUNTIME_IP"
```

A self-signed key and certificate are generated for your convenience. You can
use your own certificate and key if you override `$RUNTIME_SSL_CERT` and
`$RUNTIME_SSL_KEY` environment variables.

The curl command above uses `--resolve` for ip address resolution
and `--cacert` for trusting the certificate.

To be able to execute requests transparantly at your development machine,
you need:

1. Add the `RUNTIME_SSL_CERT` certificate your machine truststore;
2. Add the `RUNTIME_IP` with the `RUNTIME_HOST_ALIAS` to
your machine's `/etc/hosts` file.

## Optional Customization

The following arguments can all be overridden (otherwise the indicated defaults
are used):

### Networking

You can override the network and subnetwork used to peer your Apigee X organization:

```sh
export NETWORK=default
export SUBNET=default

export PROXY_MACHINE_TYPE=e2-micro
export PROXY_PREEMPTIBLE=true
```

### Regions and Zones

You can override the following locations:

```sh
# Used for regional resources like routers and subnets
export REGION=europe-west1
# Used as the Apigee X runtime location (trial orgs are zonal only)
export ZONE=europe-west1-b
# Used as the Apigee alalytics region (see docs for allowed values)
export AX_REGION=europe-west1
```

### Certificates and Hostname

The following certificate options are supported and can be configured through
the `CERTIFICATES` environment variable:

<!-- markdownlint-disable MD013 -->
|`CERTIFICATES` value|Description|Hostname|
|---|---|---|
|`managed` (default)|Google-managed Certificates|\[external ip\].nip.io (use nip.io for test purposes only)|
|`generated`|Auto-Generated Self-Signed Certs|$RUNTIME_HOST_ALIAS or else $ORG-eval.apigee.net|
|`supplied`|User-supplied in `RUNTIME_SSL_CERT` and `RUNTIME_SSL_KEY`|$RUNTIME_HOST_ALIAS or else $ORG-eval.apigee.net|
<!-- markdownlint-enable MD013 -->
