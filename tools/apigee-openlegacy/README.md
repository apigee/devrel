# Apigee OpenLegacy

A set of tooling and reference material for Apigee and OpenLegacy integration.

## API Facade on Mainframe

A common pattern in a Digital Transformation is the Facade pattern. This allows APIs to be consistently managed
by an API Management platform, regardless of the technology used in the backend. This might be a collection of
Microservices in Cloud Functions, SOAP services and even mainframe integrations.

<diagram>

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

<screenshot of OpenLegacy openapi spec>
<screenshot of Apigee trace>

## Extend

- pointer to API Jam material for Developer Portal, Ax, Traffic Management etc.
- discussion of defining OpenLegacy as a target server for a large org
- discussion of Apigee Proxy templating for a large org
