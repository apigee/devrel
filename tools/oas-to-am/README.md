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

Takes an OpenAPI Specification [(see example)](./test/petstore.json) and a
single Operation and parses it to generate an AssignMessage Policy
[(see example)](./test/expected.xml).

## Purpose

- Generate Target Request and Service Callout templates based on API Specifications
- Now it is very easy to use out of the box Apigee policies to set the variables
needed
- It is also easy to take an OpenAPI spec from a tool like OpenLegacy and
kickstart the integration with Apigee
