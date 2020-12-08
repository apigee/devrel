# OIDC Mock

A simple OIDC mock identity provider implementation.
Standard endpoints are exposed, like:
- Authorize
- Token
- Introspection
- UserInfo
- Certs 
- Discovery document

## Dependencies

- [Maven](https://maven.apache.org/)
- [NodeJS](https://nodejs.org/en/) LTS version or above
- Apigee Evaluation [Organization](https://login.apigee.com/sign__up)

## Quick start

    export APIGEE_ORG=xxx
    export APIGEE_ENV=xxx
    export APIGEE_USER=xxx
    export APIGEE_PASS=xxx
    mvn install -P"$APIGEE_ENV" -Dapigee.config.options=update
    npm i
    npm test


## OIDC Mock documentation

...
