# Proxy Template

A simple tool to create an Apigee API Proxy from a template.

The provided template uses Shared Flows for:

- CORS Headers
- Correlation Identification
- Standardised Error Handling
- Resource Not Found
- Ping and Status Monitoring Endpoints
- Traffic Management
- OAuth 2 Token Verification

It also has the following features:

- Deploys with Node JS using `apigeetool`
- Includes BDD integration tests using `apickli`
- Easily extensible by editing the `template-v1` proxy or `generate-proxy`
  script

## Dependencies

- [Common Shared Flows](../common-shared-flows)
- [NodeJS](https://nodejs.org/en/) LTS version or above
- Apigee Evaluation [Organization](https://login.apigee.com/sign__up)

## Quick start

    ./generate-proxy.sh

    # Answer questions and note that ./xxx-v1/ has been created for you

    # To deploy and test
    cd ./xxx-v1
    export APIGEE_ORG=xxx
    export APIGEE_ENV=xxx
    export APIGEE_USER=xxx
    export APIGEE_PASS=xxx
    npm run deploy
    npm test
