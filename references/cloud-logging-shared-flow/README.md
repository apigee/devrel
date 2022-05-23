# Cloud Logging Shared Flow

***Note:*** Apigee X and hybrid >= 1.7.0 support logging to Google Cloud Logging
via the default [MessageLogging Policy](https://cloud.google.com/apigee/docs/api-platform/reference/policies/message-logging-policy).
The service callout used in this implementation is no longer required for
these versions of Apigee.

Reference implementation for a shared flow to log to [Google Cloud Logging](https://cloud.google.com/logging)
from within an Apigee Proxy.

## Compatibility

This example is built using the [GCP Service Account Association](https://cloud.google.com/apigee/docs/api-platform/security/google-auth/overview)
that is available in Apigee X and newer versions of hybrid.
For scenarios where this option is not available you can make use of the
[GCP SA shared flow](../gcp-sa-auth-shared-flow) to obtain a valid access
token and use it within the ServiceCallout policy.

## Usage

```sh
alias sackmesser=${PWD}/../../tools/apigee-sackmesser/bin/sackmesser

export APIGEE_X_ORG=<my-org>
export APIGEE_X_ENG=<my-env>
export APIGEE_X_HOSTNAME=<my-hostname>

export CLOUD_LOG_WRITER_SA=<gcp service account email to be used by the logger>

./pipeline.sh
```
