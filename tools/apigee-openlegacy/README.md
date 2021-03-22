# Apigee OpenLegacy

A set of tooling and reference material for Apigee and OpenLegacy integration.

## API Facade on Mainframe

A common pattern in a Digital Transformation is the Facade pattern. This allows APIs to be consistently managed
by an API Management platform, regardless of the technology used in the backend. This might be a collection of
Microservices in Cloud Functions, SOAP services and even mainframe integrations.

![Mainframe Modernization](https://cloudx-bricks-prod-bucket.storage.googleapis.com/ae75bf0d3a5f305db7989c35f15d36839e46828ff0ff6bc93a0803df11001217.svg | width="100")

By combining Apigee and OpenLegacy, we can apply API Management policies such as OAuth 2.0 security, Developer Portal
onboarding, Analytics and Traffic Management to our mainframe!

## Architecture Patterns

### Serverless

<diagram of Managed Apigee with Cloud Functions and Service Accounts>

### Hybrid

<diagram of Apigee Hybrid with OpenLegacy in GKE>

### On Premise

<diagram of Apigee with OpenLegacy on premise with MTLS>

## Prerequisites

- Create a free Apigee Account
- Create OpenLegacy API Key 
- Download OpenLegacy CLI from [here]()
- Install Maven and Git

## Usage

```
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

./apigee-openlegacy 

``` 
## Result

- OpenLegacy Module and Project created
- OpenLegacy connector deployed to Cloud Run
- Apigee Proxy Configured with service account keys to connect to Cloud Run

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

