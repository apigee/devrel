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

- Deploys on Apigee Edge, X or hybrid using `maven` or `sackmesser`
- Includes BDD integration tests using `apickli`
- Easily extensible by editing the `template-v1` proxy or `generate-proxy`
  script
- Uses a TargetServer, which is deployed and whose properties (name, host,
port, ssl enabled or not) are based on the environment variable `TARGET_URL`
  - The path that is set in `TARGET_URL` is used to configure a conditional flow
on the proxy template. This flow is used to test the TargetServer
  - The default value of `TARGET_URL` is `https://httpbin.org/headers`

## Dependencies

- [Maven](https://maven.apache.org/)
- [Common Shared Flows](../common-shared-flows)
- [NodeJS](https://nodejs.org/en/) LTS version or above

## Quick start

### Deploy to Apigee X / hybrid

    # Set APIGEE_X_YYY env variables
    export APIGEE_X_ORG=xxx
    export APIGEE_X_ENV=xxx
    export APIGEE_X_HOSTNAME=api.example.com

    ./generate-proxy.sh --googleapi

    # Answer questions and note that ./xxx-vn/ has been created for you

    # To deploy...
    APIGEE_TOKEN=$(gcloud auth print-access-token)

    sackmesser deploy --googleapi \
    -o "$APIGEE_X_ORG" \
    -e "$APIGEE_X_ENV" \
    -t "$APIGEE_TOKEN" \
    -h "$APIGEE_X_HOSTNAME" \
    -d ./xxx-vn

    # ...and test
    cd ./xxx-vn
    TEST_HOST="$APIGEE_X_HOSTNAME" npm test

### Deploy to Apigee Edge

    # Set APIGEE_XXX env variables
    export APIGEE_ORG=xxx
    export APIGEE_ENV=xxx
    export APIGEE_USER=xxx
    export APIGEE_PASS=xxx

    # Generate an API proxy based on proxy template
    ./generate-proxy.sh --apigeeapi

    # Answer questions and note that ./xxx-vn/ has been created for you

    # To deploy...
    sackmesser deploy --apigeeapi \
    -o "$APIGEE_ORG" \
    -e "$APIGEE_ENV" \
    -u "$APIGEE_USER" \
    -p "$APIGEE_PASS" \
    -d ./xxx-vn

    # ...and test
    cd ./xxx-vn
    TEST_HOST="$APIGEE_ORG-$APIGEE_ENV.apigee.net" npm test
