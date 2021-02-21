# OpenAPI Specification to Assign Message

A simple tool to generate an Assign Message policy from a JSON OpenAPI (3.0) Spec.

## Usage

``` sh
git clone https://github.com/apigee/devrel
cd devrel/tools/oas-to-am
export PATH=$PATH:$PWD/bin #you can add this to your .bashrc too
SPEC=./path/to/spec.json OPERATION=operationId oas-to-am
```

## Dependencies

- jq
- libxml2-utils

## Current Behaviour

Takes the OAS spec [here](./test/features/fixtures/petstore.json) and a
single Operation, parses it to generate [this](./test/features/fixtures/expected.xml)
. The behaviour is described [here](./test/features/OASToAM.feature).

## Purpose

- Generate Target Request and Service Callout templates based on API Specifications
- Now it is very easy to use out of the box Apigee policies to set the variables
needed
- It is also easy to take an OpenAPI spec from a tool like OpenLegacy and
kickstart the integration with Apigee
