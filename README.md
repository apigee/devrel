# Apigee DevRel
<!--
  Copyright 2024 Google LLC

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
-->

[![In Solidarity](https://github.com/jpoehnelt/in-solidarity-bot/raw/main/static//badge-flat.png)](https://github.com/apps/in-solidarity)

Common solutions and tools developed by Apigee.

## References

This folder contains reference solutions across a variety of Apigee products.
It is expected that these solutions are used as an illustration or extended
further to fit a particular use case.

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
- [CI/CD Pipeline for Shared Flows](references/cicd-sharedflow-pipeline) -
  Reference implementation for a CI/CD Pipeline for Sharedflows using the Apigee
  Deploy Maven Plugin
- [Cloud Logging Shared Flow](references/cloud-logging-shared-flow) -
  Reference implementation for a shared flow to log to Google Cloud Logging
- [Cloud Run](references/cloud-run) -
  Reference implementation for using Apigee to expose a Cloud Run Service
- [Data API](references/data-api) - A reference implementation for using
  Apigee to facilitate the consumption of data from a data platform.
- [Data Converters Shared Flow](references/data-converters-shared-flow) -
  A reference shared flow for doing common response data JSON conversions
- [Product Recommendations](references/product-recommendations) -
  Smart API to Predict Customer Propensity to buy using Apigee, BigQuery ML and Cloud Spanner
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
- [OAuth Admin API](references/oauth-admin-api) -
  API proxy to enable the revocation of Apigee-issued access tokens by
  application or end user id.
- [Dutch Healthcare Reference](references/dutch-healthcare) -
  An API reference to accelerate implementation of Dutch Healthcare standards.
- [XML & JSON Threat Protection](references/threat-protect) -
  A reference for protecting API proxies against XML and JSON threats
- [Auth Schemes](references/auth-schemes) - Example implementations for various
  popular API auth schemes
- [reCAPTCHA enterprise](references/recaptcha-enterprise) - A reference for
  API protection against bot leveraging reCAPTCHA enterprise
- [Firestore Facade](references/firestore-facade) - Reference implementation
  for a long term caching/storage solution based on Cloud Firestore
- [OpenAPI Mock](references/openapi-mock) - Reference implementation
    for creating a mock API proxy from an OpenAPI 3 specification

## Tools

This folder contains ready-made utilities which simplify and assist the usage of
Apigee products.

- [Pipeline Runner](tools/pipeline-runner) -
  A tool to build and test groups of Apigee projects
- [Pipeline Linter](tools/pipeline-linter) -
  A tool to lint groups of Apigee projects
- [Apigee hybrid Terraform Script](tools/apigee-hybrid-terraform) -
  Apigee Hybrid Terraform script to deploy Apigee hybrid on GKE,AKS,EKS and Bring Your Own Cluster
- [Apigee hybrid Quickstart GKE](tools/hybrid-quickstart) -
  A quickstart setup configuration for Apigee hybrid on GKE
- [Decrypt Hybrid Assets](tools/decrypt-hybrid-assets) -
  A rescue utility to decrypt proxies and shared flows
- [Apigee X Trial Provisioning Reference](tools/apigee-x-trial-provision) -
  A reference provisioning script for Apigee X trial provisioning
- [Apigee Sackmesser](tools/apigee-sackmesser) -
  A unified proxy deployment utility for Edge, hybrid and X
- [Apigee OpenLegacy Kickstart](tools/apigee-openlegacy) -
  A kickstart script to integrate OpenLegacy, Apigee and Cloud Run
- [OpenAPI to Apigee Mock Proxy](tools/oas-apigee-mock) -
  A utility to generate an Apigee Proxy bundle with mock responses from a spec
- [Cloud Endpoints OpenAPI Importer](tools/endpoints-oas-importer) -
  A utility to generate Apigee Proxies based on OAS with Cloud Endpoints OAS
  extensions
- [Generate Shared Flows Dependency List](tools/sf-dependency-list) -
  A tool to generate topologically sorted Shared Flow dependencies.
- [Apigee Envoy Quickstart Toolkit](tools/apigee-envoy-quickstart) -
  A tool to set up the sample deployments of Apigee Envoy.
- [Apigee API Proxy Endpoint Unifier](tools/proxy-endpoint-unifier) -
  A tool to unify/split proxy endpoints based on API basepath.
- [Apigee Target Server Validator](tools/target-server-validator) -
  A tool to validate all targets in Target Servers & Apigee API Proxy Bundles.
- [gRPC to HTTP Gateway Generator](tools/grpc-http-gateway-generator) -
  Generate gateways to expose gRPC services with HTTP API management.
## Labs

This folder contains raw assets used to generate content to teach a particular
technical or non-technical topic.

- [Best Practices Hackathon](labs/best-practices-hackathon) [(web)](https://apigee.github.io/devrel/labs/best-practices-hackathon)
  A 300 level lab to learn Apigee Best Practices
- [BDD Proxy Development](labs/bdd-proxy-development) [(web)](https://apigee.github.io/devrel/labs/bdd-proxy-development)
  A 200 level lab demonstrating behavior-driven API development by building,
  deploying and testing a mock API, generated from an Open API Specification.
- [Identity facade with Okta](labs/idp-okta-integration) [(web)](https://apigee.github.io/devrel/labs/idp-okta-integration)
  A 300 level lab that shows how to configure the Apigee Identity Facade with Okta IDP.
- [Eventarc + API Hub integration](labs/eventarc-apihub) - A lab for a workflow-based automation to deploy proxies using API hub and Eventarc
## Contributing

See the [contributing instructions](./CONTRIBUTING.md) to get started.

## License

All solutions within this repository are provided under the
[Apache 2.0](https://www.apache.org/licenses/LICENSE-2.0) license.
Please see the [LICENSE](./LICENSE) file for more detailed terms and conditions.

## Disclaimer

This repository and its contents are not an official Google product.

## Contact

Questions, issues and comments should be directed to
[apigee-devrel-owners@google.com](mailto:apigee-devrel-owners@google.com).
