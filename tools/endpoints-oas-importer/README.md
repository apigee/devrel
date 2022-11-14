# Cloud Endpoints to Apigee Proxy Bundle Importer

Cloud Endpoints adds a number of OpenAPI [extensions](https://cloud.google.com/endpoints/docs/openapi/openapi-extensions)
that are used to configure the API proxy behavior.

This tool can be used to import an OpenAPI specification with cloud Cloud
Endpoints extensions to generate Apigee proxies.

## Prerequisites

* [jq](https://github.com/stedolan/jq) (needed to process OAS in JSON and YAML format)
* [yq](https://github.com/mikefarah/yq) (only needed to process OAS in YAML format)

## What is currently supported

* default target backend via `x-google-backend.address`
  and `x-google-backend.path_translation`
* path level dynamic routing via `x-google-backend.address`
  and `x-google-backend.path_translation`
* intercept unmatched paths via `x-google-allow`

## How to use it

The endpoints importer expects the following parameters:

```txt
--oas/-o            the path of an OpenAPI 2.0 file in json or yaml format
--base-path/-b      the basepath that should be extracted from
                    the OAS paths and used in the proxy
--name/-n           the name of the proxy to be created
--quiet/-q          (optional) skip the override confirmation
```

With a JSON OAS file

```sh
./import-endpoints.sh --oas ./examples/openapi_test.json --base-path /headers --name oas-import-test
```

With a YAML OAS file

```sh
./import-endpoints.sh --oas ./examples/openapi_test.yaml --base-path /headers --name oas-import-test
```

