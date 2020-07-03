# Identity Platform Mock with API Mocker

This reference project leverages [apimocker](https://npmjs.com/package/apimocker) to provide dynamic mocks, deployed to Apigee.

The APIs are based on Keycloak.

## Dependencies

-   [NodeJS](https://nodejs.org/en/) LTS version or above
-   Apigee Evaluation [Organization](https://login.apigee.com/sign__up)

## Quick Start

    export APIGEE_ORG=xxx
    export APIGEE_ENV=xxx
    export APIGEE_USER=xxx
    export APIGEE_PASS=xxx
    npm run deploy
    npm test

## Further Reading

-   <https://community.apigee.com/articles/27779/how-to-mock-a-target-backend-with-a-nodejs-api-pro.html>
-   <https://www.npmjs.com/package/apimocker>
