# Apigee X Trial Provisioning

> Note - this script is not subject to pipelines

## Description

This script creates an Apigee X trial organization and instance. It uses
gcloud command to create a hybrid runtime and adds an enovoy proxy and
Google Cloud Load Balancer,
[GCLB](https://cloud.google.com/load-balancing/docs) for external exposure.

The script follows the documentation installation steps. The relevant step
numbers are added for easier cross-reference.

If you provisioned an organization using [Apigee eval provisioning wizard](https://cloud.google.com/apigee/docs/api-platform/get-started/eval-orgs#wiz),
you can run this script to add envoy proxies and GCLB configuration for
external exposure.

A reference example of [Command Line](https://cloud.google.com/apigee/docs/api-platform/get-started/install-cli)
Provisioning for Apigee X.

Please refer to the documentation for the latest usage.

## Usage

You need to set up a PROJECT environment variable.

```sh
export PROJECT=<gcp-project-name>
```

## Optional Arguments

The following arguments can all be overridden:

```sh
export NETWORK=
export SUBNET=
export REGION=
export ZONE=
export AX_REGION=
```

```sh
 ./apigee-x-trial-provision.sh
```

> NOTE: To invoke the script directly from the github repo, use
>
> ```sh
> curl -L https://raw.githubusercontent.com/apigee/devrel/main/tools/apigee-x-trial-provision/apigee-x-trial-provision.sh | bash -
> ```

WARNING: A successful `Provisioning organization...` step takes 25-30 minutes
to complete. According to the documentation: "This is a long running operation
and could take anywhere from 10 minutes to 1 hour to complete." [->](https://cloud.google.com/sdk/gcloud/reference/alpha/apigee/organizations/provision)

After the script runs, it displays LB IP, certificate location and
used `RUNTIME_HOST_ALIAS`, as well as an example of send a test
request to an automatically deployed hello-world proxy.

When the script finishes, it takes extra 5-7 minutes to provision
the load balancing infrastructure. You can use the following curl command
to run it until 200 OK is returned to ensure that Apigee X install
is fully completed.

Sample Output:

```sh
export RUNTIME_IP=203.0.113.10

export RUNTIME_SSL_CERT=~/mig-cert.pem
export RUNTIME_HOST_ALIAS=$PROJECT-eval.apigee.net

curl --cacert $RUNTIME_SSL_CERT https://$RUNTIME_HOST_ALIAS/hello-world -v --resolve "$RUNTIME_HOST_ALIAS:443:$RUNTIME_IP"
```

A self-signed key and certificate are generated for your convenience. You can
use your own certificate and key if you override $RUNTIME_SSL_CERT and
$RUNTIME_SSL_KEY environment variables.

The curl command above uses --resolve for ip address resolution
and --cacert for trusting the certificate.

To be able to execute requests transparantly at your development machine,
you need:

1. Add the `RUNTIME_SSL_CERT` certificate your machine truststore;
2. Add the `RUNTIME_IP` with the `RUNTIME_HOST_ALIAS` to
your machine's `/etc/hosts` file.
