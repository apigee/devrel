# Airports CI/CD V1 Proxy

This contains an example proxy for the CI/CD pipeline reference using Jenkins
and Maven.

## Development

- Install dependencies: `npm install`
- Unit testing: `npm run unit-test`
- Integration testing against host `$APIGEE_ORG-$APIGEE_ENV.apigee.net` and
  default basepath `airports-cicd/v1`:
  `TEST_HOST=$APIGEE_ORG-$APIGEE_ENV.apigee.net npm run integration-test`
- Integration testing against feature branch deployment on
  `airports-cicd-feature-ABC/v1`:

``` sh
TEST_HOST=$APIGEE_ORG-$APIGEE_ENV.apigee.net TEST_BASE_PATH='/airports-cicd-feature-ABC/v1' npm run integration-test
```
