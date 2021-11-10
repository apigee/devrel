# Apigee X and Cloud Run

Reference Implementation for how to front a Cloud Run service with Apigee X.

## Compatibility

This example is built using the [GCP Service Account Association](https://cloud.google.com/apigee/docs/api-platform/security/google-auth/overview)
that is available in Apigee X and hybrid. For scenarios where this option is not
available you could make use of the [GCP SA shared flow](../gcp-sa-auth-shared-flow)
to obtain a valid access token and use it within the ServiceCallout policy.

For more background information please see [this](https://www.googlecloudcommunity.com/gc/Cloud-Product-Articles/Hosted-Targets-vs-Google-Cloud-Run/ta-p/76040)
Community Article.

## Usage

See the community article linked above for step by step instructions
or use the pipeline.sh script to deploy a simple example.

```sh
export APIGEE_X_ORG=<my-org>
export APIGEE_X_ENG=<my-env>
export APIGEE_X_HOSTNAME=<my-hostname>
export DELETE_AFTER_TEST=false

./pipeline.sh
```
