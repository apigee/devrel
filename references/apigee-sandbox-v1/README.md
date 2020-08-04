# Apigee Sandbox

## Description

An API Mock generated from a Swagger 2 specification and hosted in Apigee

## Dependencies

- [NodeJS](https://nodejs.org/en/) LTS version or above
- Apigee Evaluation [Organization](https://login.apigee.com/sign__up)

## Quick start

Replace `apiproxy/resources/node/swagger.json` with your specification file.

    export APIGEE_ORG=xxx
    export APIGEE_ENV=xxx
    export APIGEE_USER=xxx
    export APIGEE_PASS=xxx
    npm run deploy
    npm test
