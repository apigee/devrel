# CI/CD Demo V1 Proxy

This contains an example proxy for the CI/CD pipeline demo.

## Development

*   Install dependencies: `npm install`
*   Unit testing: `npm run unit-test`
*   Integration testing against host `my-org-env.apigee.net` and default basepath `cicd-demo/v1`: 
    `TEST_HOST=my-org-env.apigee.net npm run integration-test`
*   Integration testing against feature branch deployment on `cicd-demo-feature-ABC/v1`:
    `TEST_HOST=my-org-env.apigee.net TEST_BASE_PATH='/cicd-demo-feature-ABC/v1' npm run integration-test`
