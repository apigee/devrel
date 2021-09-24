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
- Uses a TargetServer, which is deployed and whose properties (name, host,
port, ssl enabled or not) are based on the environment variable `TARGET_URL`
  - The path that is set in `TARGET_URL` is used to configure a conditional flow
on the proxy template. This flow is used to test the TargetServer
  - The default value of `TARGET_URL` is `https://httpbin.org/headers`

## Dependencies

- [Common Shared Flows](../common-shared-flows)
- [NodeJS](https://nodejs.org/en/) LTS version or above
- Apigee Evaluation [Organization](https://login.apigee.com/sign__up)

## Quick start

    # Set APIGEE_XXX env variables
    export APIGEE_ORG=xxx
    export APIGEE_ENV=xxx
    export APIGEE_USER=xxx
    export APIGEE_PASS=xxx

    # Generate an API proxy based on proxy template
    . ./generate-proxy.sh

    # Answer questions and note that ./xxx-vn/ has been created for you

    # To deploy and test
    cd ./xxx-vn
    npm run deployTargetServer
    npm run deployProxy
    npm test
