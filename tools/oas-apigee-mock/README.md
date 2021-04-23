# OpenAPI to Apigee Mock Proxy

A tool which generates an Apigee API Proxy bundle from an Open API 3
specification, with mock responses using Assign Message policies from the
examples provided in the specification.

## Dependencies

- [NodeJS](https://nodejs.org/en/) LTS version or above
- Apigee Evaluation [Organization](https://login.apigee.com/sign__up)

## Prerequisites

Clone the code from this GitHub repo and run `npm install` to download and
install the required dependencies.

## Usage

```bash
node bin/oas-apigee-mock generateApi <proxy-name> \
  -s <api-spec> \
  -d <destination-dir> \
  -b <base-path>
```

### Example

```bash
node bin/oas-apigee-mock generateApi retail -s test/orders.yaml
```
