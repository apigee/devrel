# Common Shared Flows

A set of useful shared flows for Apigee.

## Dependencies

- [NodeJS](https://nodejs.org/en/) LTS version or above
- Apigee Evaluation [Organization](https://login.apigee.com/sign__up)

## Quick Start

### Deploy to Apigee X or hybrid

#### Set Config Variables

    export APIGEE_X_ORG=xxx
    export APIGEE_X_ENV=xxx
    export APIGEE_TOKEN=$(gcloud auth print-access-token);

    ./deploy.sh all --googleapi

### Deploy to Apigee Edge

#### Set Config Variables

    export APIGEE_ORG=xxx
    export APIGEE_ENV=xxx
    export APIGEE_USER=xxx
    export APIGEE_PASS=xxx

    ./deploy.sh all --apigeeapi

## Shared Flows

### Correlation

Sets a header called `X-Correlation-Id` that can be used for logging and
application monitoring

### CORS

Set `Access-Control-*` headers for Preflight and Standard API Requests

### Error Handling

Seperate the throwing of errors, description and formatting of errors for
consistency across API Proxies.

### Get Config

Read Key Value Map configuration values for an environment in one step to reduce
database reads.

### Logging

Set a standardised logging payload which can be sent over HTTP to any logging
platform.

### Not Found

Set a standardised 404 Not Found error.

### Monitoring

[Ping and Status](https://community.apigee.com/articles/17862/forming-an-api-monitoring-strategy-where-to-start.html)
endpoints.

### Traffic Management

A configurable Spike Arrest policy.

### Verify Token

Checks if an OAuth token is valid against its expiry, list of API Products and
Developer App approval.
