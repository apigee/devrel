# OpenAPI to Apigee Mock Proxy

A tool which generates an Apigee API Proxy bundle from an Open API 3
specification, with mock responses using Assign Message policies from the
examples provided in the specification. A Verify API key policy will
be added to the Proxy PreFlow if the OAS provided specifies ApiKeyAuth
should be applied globally to all operations.

## Dependencies

- [NodeJS](https://nodejs.org/en/) LTS version or above
- [Apigee Organization](https://cloud.google.com/apigee/pricing)

## Prerequisites

Clone the code from this GitHub repo and run `npm install` to download and
install the required dependencies.

## Usage

```bash
node bin/oas-apigee-mock generateApi <proxy-name> \
  -s <api-spec> \
  -d <destination-dir> \
  -b <base-path> \
  -o
```

### Parameters

`--source    -s`
(required) The Open API specification from which to generate the proxy bundle.

`--destination    -d`
(optional) The destination directory for the generated proxy bundle.

`--basepath    -b`
(optional) The basepath to be used in the generated proxy bundle.

`--oas-validation    -o`
(optional) Include policies to enforce request validation in the proxy bundle,
using the Open API specification provided.

### Example

```bash
node bin/oas-apigee-mock generateApi retail -s test/orders.yaml -o
```
