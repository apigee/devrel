<!-- markdownlint-disable MD033 -->
# Apigee OpenLegacy

A set of tooling and reference material for Apigee and OpenLegacy integration.

## API Facade on Mainframe

A common pattern in a Digital Transformation is the Facade pattern. This allows
APIs to be consistently managed by an API Management platform, regardless of the
technology used in the backend. This might be a collection of microservices in
Cloud Run, SOAP services and even mainframe integrations.

<p align="center">
<img alt="Modernization" src="https://cloudx-bricks-prod-bucket.storage.googleapis.com/ae75bf0d3a5f305db7989c35f15d36839e46828ff0ff6bc93a0803df11001217.svg"
  width="75%">
</p>

By combining Apigee and OpenLegacy, we can apply API Management policies such as
OAuth 2.0 security, Developer Portal onboarding, Analytics and Traffic
Management to our mainframe!

## Prerequisites

- Create a free Apigee Account
- Create OpenLegacy API Key
- Download OpenLegacy CLI from [the hub](https://app.ol-hub.com/)
- Install Maven and Git

## Quickstart Usage

For the best compatibility, run from a Google Cloud Shell

```sh
export OPENLEGACY_APIKEY=
export OPENLEGACY_HOST=
export OPENLEGACY_USER=
export OPENLEGACY_PASS=
export OPENLEGACY_CODEPAGE=
export APIGEE_USER=
export APIGEE_PASS=
export APIGEE_ORG=
export APIGEE_ENV=
export GCP_PROJECT=

git clone https://github.com/apigee/devrel
sh ./devrel/tools/apigee-openlegacy/pipeline.sh
```

## Result

- OpenLegacy Module and Project created
- OpenLegacy connector deployed to Cloud Run
- Apigee Proxy Configured with service account keys to connect to Cloud Run,
  Spike Arrest and API Key check
- API Product, Developer and App configured

## Extend

Consider adding or customising policies for:

- Northbound API Security
- Traffic Management
- Custom Analytics
- Mediation and Orchestration
- API Versioning
- Developer Portal
- Monetization

You may also consider configuring OpenLegacy as a TargetServer to be shared by
proxies developed by multiple teams in a large organization.
