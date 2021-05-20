# Dutch Healthcare API Reference

## Description

An API reference to accelerate implementation of Dutch Healthcare API standards.

This API Proxy sits in front of our FHIR Target. You can change the Target URL
[here](./healthcare-v1/apiproxy/targets/default.xml).

## Features

By default, this API proxy uses [Shared Flows](../common-shared-flows) for:

- CORS Headers
- Correlation Identification
- Standardised Error Handling
- Resource Not Found
- Ping and Status Monitoring Endpoints
- Traffic Management

### Mediation

You may wish to use Apigee to act as a facade in front of multiple systems. In
order to route specific requests to different systems, see [here](./healthcare-v1/apiproxy/proxies/default.xml)

Additionally, you may wish to enrich a response with additional information from
another system using a ServiceCallout or JavaScript. See [here](./healthcare-v1/apiproxy/resources/jsc/EnrichAllergyResponse.js)
for an example.

## Dependencies

- [Common Shared Flows](../common-shared-flows)

## Prerequisites

Ensure that [`apigee-sackmesser`](https://github.com/apigee/devrel/tree/main/tools/apigee-sackmesser)
is on your `PATH`.

## Quick Start

```sh
# For Edge
export APIGEE_ORG=
export APIGEE_ENV=
export APIGEE_USER=
export APIGEE_PASS=
./pipeline.sh --apigeeapi
```

```sh
# For X/hybrid
export APIGEE_ORG=
export APIGEE_ENV=
export APIGEE_TOKEN=$(gcloud auth print-access-token)
./pipeline.sh --googleapi
```
