# Apigee DevRel

[![DevRel All Projects Pipeline](https://github.com/apigee/devrel/workflows/DevRel%20All%20Projects%20Pipeline/badge.svg)](https://github.com/apigee/devrel/actions?query=workflow%3A%22DevRel+All+Projects+Pipeline%22)
[![DevRel Github Pages Pipeline](https://github.com/apigee/devrel/workflows/DevRel%20Github%20Pages%20Pipeline/badge.svg)](https://github.com/apigee/devrel/actions?query=workflow%3A%22DevRel+Github+Pages+Pipeline%22)
[![In Solidarity](https://github.com/jpoehnelt/in-solidarity-bot/raw/main/static//badge-flat.png)](https://github.com/apps/in-solidarity)

Common solutions and tools developed by Apigee.

## References

This folder contains reference solutions across a variety of Apigee products.
It is expected that these solutions are used as an illustration or extended
further to fit a particular use case.

- [Swagger 2 based Mocks on Apigee Hosted Targets](references/apigee-sandbox-v1)
  - Swagger 2 based Mocks on Apigee SaaS
- [API Mocker on Apigee Hosted Targets](references/apimocker-hostedtargets) -
  API Mocks hosted on Apigee SaaS
- [Common Shared Flows](references/common-shared-flows) -
  Reusable API Policies including Security, Traffic Management, Error Handling
  and CORS
- [Custom Java Extensions in Apigee](references/java-callout) -
  A reference project that includes a Java Extension
- [GCP Service Account Shared Flow](references/gcp-sa-auth-shared-flow) -
  A shared flow to obtain access tokens for GCP service accounts.
- [Jenkins CI/CD Pipeline](references/cicd-jenkins) -
  Reference implementation for a CI/CD Pipeline using Jenkins and the Apigee
  Deploy Maven Plugin
- [Proxy Template](references/proxy-template) -
  An extensible templating tool to bootstrap API proxies containing Security,
  Traffic Management, Error Handling
- [Writing JavaScript in Apigee](references/js-callout) -
  Demonstrate best practices in writing JavaScript code in Apigee context
- [Southbound mTLS](references/southbound-mtls) -
  Reference for using mTLS client authentication for securely connecting Apigee to
  backend services
- [Identity Proxy](references/dummy) -
  Reference for using Apigee as an identity proxy for end-user authentication
  via OIDC
- [OIDC Mock Identity Proxy](references/oidc-mock) -
  Reference project that includes an oidc mock identity provider

## Tools

This folder contains ready-made utilities which simplify and assist the usage of
Apigee products.

- [Organization Cleanup](tools/organization-cleanup) -
  A tool to cleanup proxies in an Apigee organization, leveraging
  [Another Apigee Client](tools/another-apigee-client)
- [Pipeline Runner](tools/pipeline-runner) -
  A tool to lint, build and test groups of Apigee projects
- [Another Apigee Client](tools/another-apigee-client) -
  A lightweight Apigee Management CLI
- [Apigee hybrid Quickstart GKE](tools/hybrid-quickstart) -
  A quickstart setup configuration for Apigee hybrid on GKE

## Labs

This folder contains raw assets used to generate content to teach a particular
technical or non-technical topic.

- [Best Practices Hackathon](labs/best-practices-hackathon) [(web)](https://apigee.github.io/devrel/labs/best-practices-hackathon)
  A 300 level lab to learn Apigee Best Practices

## Contributing

See the [contributing instructions](/CONTRIBUTING.md) to get started.

## License

All solutions within this repository are provided under the
[Apache 2.0](https://www.apache.org/licenses/LICENSE-2.0) license.
Please see the [LICENSE](/LICENSE) file for more detailed terms and conditions.

## Disclaimer

This repository and its contents are not an official Google product.

## Contact

Questions, issues and comments should be directed to
[apigee-devrel-owners@google.com](mailto:apigee-devrel-owners@google.com).
