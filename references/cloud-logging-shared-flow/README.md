# Cloud Logging Shared Flow

Reference implementation for a shared flow to log to [Google Cloud Logging](https://cloud.google.com/logging)
from within an Apigee Proxy.

## Compatibility

This example is built using the [GCP Service Account Association](https://cloud.google.com/apigee/docs/api-platform/security/google-auth/overview)
that is available in Apigee X. For scenarios where this option is not
available you could make use of the [GCP SA shared flow](../gcp-sa-auth-shared-flow)
to obtain a valid access token and use it within the ServiceCallout policy.

## Usage

```sh
alias sackmesser=${PWD}/../../tools/apigee-sackmesser/bin/sackmesser

export APIGEE_X_ORG=<my-org>
export APIGEE_X_ENG=<my-env>
export APIGEE_X_HOSTNAME=<my-hostname>

export CLOUD_LOG_WRITER_SA=<gcp service account email to be used by the logger>

./pipeline.sh
```
