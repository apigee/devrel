# Apigee DevRel

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
  A shared flow to obtain access tokens for GCP service accounts
- [CI/CD Pipeline](references/cicd-pipeline) -
  Reference implementation for a CI/CD Pipeline using the Apigee
  Deploy Maven Plugin and a choice of either Jenkins or Google Cloud Build
- [Proxy Template](references/proxy-template) -
  An extensible templating tool to bootstrap API proxies containing Security,
  Traffic Management, Error Handling
- [Writing JavaScript in Apigee](references/js-callout) -
  Demonstrate best practices in writing JavaScript code in Apigee context
- [Southbound mTLS](references/southbound-mtls) -
  Reference for using mTLS client authentication for securely connecting Apigee to
  backend services
- [OIDC Mock](references/oidc-mock) -
  A simple OIDC mock identity provider implementation
- [Identity Facade](references/identity-facade) -
  Reference implementation for an Identity Facade proxy in front of an OIDC
  compliant identity provider
- [KVM Admin API](references/kvm-admin-api) -
  Generic API proxy to provide Create, Read and Delete operations for KVMs

## Tools

This folder contains ready-made utilities which simplify and assist the usage of
Apigee products.

- [Organization Cleanup](tools/organization-cleanup) -
  A tool to cleanup proxies in an Apigee organization, leveraging
  [Another Apigee Client](tools/another-apigee-client)
- [Pipeline Runner](tools/pipeline-runner) -
  A tool to build and test groups of Apigee projects
- [Pipeline Linter](tools/pipeline-linter) -
  A tool to lint groups of Apigee projects
- [Another Apigee Client](tools/another-apigee-client) -
  A lightweight Apigee Management CLI
- [Apigee hybrid Quickstart GKE](tools/hybrid-quickstart) -
  A quickstart setup configuration for Apigee hybrid on GKE
- [Decrypt Hybrid Assets](tools/decrypt-hybrid-assets) -
  A rescue utility to decrypt proxies and shared flows
- [OpenAPI to AssignMessage](tools/oas-to-am) -
  A utility to derive an AssignMessage policy from a spec
- [Apigee X Trial Provisioning Reference](tools/apigee-x-trial-provision) -
  A reference provisioning script for Apigee X trial provisioning

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
