# OpenAPI Mock API Proxy 
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

This is a [reference API Proxy implementation](./apiproxy) that lets you easily create a mock API proxy from your OpenAPI 3 specification, allowing you to simulate API behavior without a real backend.

The reference mock API proxy supports the following features.

* [CORS](#cors) (using Apigee [CORS](https://cloud.google.com/apigee/docs/api-platform/reference/policies/cors-policy) policy)
* [Request Validation](#request-validation) (using Apigee [OASValidation](https://cloud.google.com/apigee/docs/api-platform/reference/policies/oas-validation-policy))
* [Dynamic Response Status Code](#dynamic-response-status-code) (using a custom [JavaScript](https://cloud.google.com/apigee/docs/api-platform/reference/policies/javascript-policy) policy)
* [Dynamic Response Content Type](#dynamic-response-content-type) (using a custom [JavaScript](https://cloud.google.com/apigee/docs/api-platform/reference/policies/javascript-policy) policy)
* [Dynamic Response Body](#dynamic-response-body) (using a custom [JavaScript](https://cloud.google.com/apigee/docs/api-platform/reference/policies/javascript-policy) policy)


## Customizing The Mock API Proxy

This [reference implementation](./apiproxy) provides a solid foundation for building your own mock API proxy. You can customize it by adding your own policies, modifying the existing configuration, and using your own OpenAPI specification. This is a great way to learn about Apigee or to achieve more advanced customizations.

At the very minimum, you have to:

1. Update the `<BasePath>/v3/petstore</BasePath>` element within the [default.xml](./apiproxy/proxies/default.xml) proxy endpoint.
2. Replace the included sample [spec.json](./apiproxy/resources/oas/spec.json) file with your own OpenAPI 3 spec file.

> The OpenAPI 3 spec file has to be in JSON format.
> This is so that it can be used by the main JavaScript policy.


Then, you can use the [Apigee CLI](https://github.com/apigee/apigeecli/releases/) tool, and run the following command to deploy the mock API proxy. e.g.

```shell
APIGEE_ORG="target-apigee-org-name"
APIGEE_ENV="target-apigee-env"
TOKEN="$(gcloud auth print-access-token)"

apigeecli apis create bundle \
  --name my-apiproxy-v1 \
  --proxy-folder ./apiproxy \
  --org "${APIGEE_ORG}" \
  --env "${APIGEE_ENV}" \
  --ovr \
  --token "${TOKEN}" \
  --wait
```

**Looking for a faster way?**

If you just need to quickly generate a mock API proxy from your OpenAPI 3 spec, the [apigee-go-gen](https://apigee.github.io/apigee-go-gen/installation/) tool can help. 

The tool's [mock oas](https://apigee.github.io/apigee-go-gen/mock/mock-openapi-spec/) command automates the process, saving you time and effort.

Here is an example of how to generate a mock API proxy using the `apigee-go-gen` tool.

```shell
apigee-go-gen mock oas \
    --input ./examples/specs/oas3/petstore.yaml \
    --output ./out/mock-apiproxies/petstore.zip
```
It is that simple. All the information needed to generate the mock API proxy is derived from the input spec itself.

Under the hood, it is using the same reference implementation JavaScript policy from this repo.

Finally,as shown before, you would use the [Apigee CLI](https://github.com/apigee/apigeecli/releases/) to deploy the API proxy bundle.

## Mock API Proxy Features

See below for more details on each feature.

### CORS

The reference mock API proxy makes it easy to test your API from various browser-based clients.

Here's how it works:

* **Automatic CORS Headers:** The proxy automatically adds the necessary CORS headers (like `Access-Control-Allow-Origin`, `Access-Control-Allow-Methods`, etc.) to all responses.

* **Preflight Requests:** The proxy correctly handles preflight `OPTIONS` requests, responding with the appropriate CORS headers to indicate allowed origins, methods, and headers.

* **Permissive Configuration:** By default, the CORS policy is configured to be as permissive as possible, allowing requests from any origin with any HTTP method and headers. This maximizes flexibility for your testing.

The CORS policy ensures that your mock API behaves like a real API in a browser environment, simplifying your development and testing workflow.

### Request Validation

The reference mock API proxy validates the incoming requests against your specification.
This ensures that the HTTP headers, query parameters, and request body all conform to the defined rules.

This helps you catch errors in your client code early on.

You can disable request validation by passing the header:

```
Mock-Validate-Request: false
```

### Dynamic Response Status Code

The reference mock API proxy generates different status codes for your mock API responses. Here's how it works:

* **Prioritizes success:** If the [operation](https://github.com/OAI/OpenAPI-Specification/blob/main/versions/3.1.1.md#operation-object) allows `HTTP 200` status code, the proxy will use it.
* **Random selection:** If `HTTP 200` is not allowed for a particular operation, the proxy will pick a random status code from those allowed.

**Want more control?** You can use headers to select response the status code:

* **Specific status code:** Use the `Mock-Status` header in your request and set it to the desired code (e.g., `Mock-Status: 404`).
* **Random status code:** Use the `Mock-Fuzz: true` header to get a random status code from your spec.

If you use both `Mock-Status` and `Mock-Fuzz`, `Mock-Status` takes precedence.

### Dynamic Response Content-Type

The reference mock API proxy automatically selects the `Content-Type` for responses. Here is how it works:

* **JSON preferred:** If the operation allows `application/json`, the proxy will default to using it.
* **Random selection:** If `application/json` is not available, the proxy will randomly choose from the media types available for that operation.

**Want more control?** You can use headers to select the response Content-Type:

* **Standard `Accept` header:** You can use the standard `Accept` header in your request to request a specific media type (e.g., `Accept: application/xml`).
* **Random media type:** Alternatively, use the `Mock-Fuzz: true` header to have the proxy select a random media type the available ones.

If you use both `Accept` and `Mock-Fuzz`, the `Accept` header will take precedence.


### Dynamic Response Body

The reference mock API proxy generates realistic response bodies based on your OpenAPI spec.

Here's how it determines what to send back for any particular operation's response (in order):

1. **Prioritizes `example` field:** If the response includes an `example` field, the proxy will use that example.

2. **Handles multiple `examples`:** If the response has an `examples` field with multiple examples, the proxy will randomly select one. You can use the `Mock-Example` header to specify which example you want (e.g., `Mock-Example: my-example`).

3. **Uses schema examples:** If no response examples are provided, but the schema for the response has an `example`, the proxy will use that.

4. **Generates from schema:** As a last resort, the proxy will generate a random example based on the response schema. This works for JSON, YAML, and XML.

You can use the `Mock-Fuzz: true` header to force the proxy to always generate a random example from the schema, even if other static examples are available.


### Repeatable API Responses

The reference mock API proxy uses a special technique to make its responses seem random, while still allowing you to get the same response again if needed. Here's how it works:

* **Pseudo-random numbers:** The "random" choices the proxy makes (like status codes and content) are actually generated using a pseudo-random number generator (PRNG). This means the responses look random, but are determined by a starting value called a "seed."

* **Unique seeds:** Each request uses a different seed, so responses vary. However, the seed is provided in a special response header called `Mock-Seed`.

* **Getting the same response:** To get an identical response, simply include the `Mock-Seed` header in a new request, using the value from a previous response. This forces the proxy to use the same seed and generate the same "random" choices, resulting in an identical response.

This feature is super helpful for:

* **Testing:** Ensuring your tests always get the same response.
* **Debugging:** Easily recreating specific scenarios to pinpoint issues in application code.

Essentially, by using the `Mock-Seed` header, you can control the randomness of the mock API responses, making them repeatable for testing and debugging.

### Example Generation from JSON Schemas

The following fields are supported when generating examples from a JSON schema:

* `$ref` - local references are followed
* `$oneOf` - chooses a random schema
* `$anyOf` - chooses a random schema
* `$allOf` - combines all schemas
* `object` type
    * `required` field - all required properties are chosen
    * `properties` field - a random set of properties is chosen
    * `additionalProperties` field - only used when there are no `properties` defined
* `array` type
    * `minItems`, `maxItems` fields - array length chosen randomly between these values
    * `items` field - determines the type of array elements
    * `prefixItems` (not supported yet)
* `null` type
* `const` type
* `boolean` type - true or false randomly chosen
* `string` type
    * `enum` field - a random value is chosen from the list
    * `pattern` field (not supported yet)
    * `format` field
        * `date-time` format
        * `date` format
        * `time` format
        * `email` format
        * `uuid` format
        * `uri` format
        * `hostname` format
        * `ipv4` format
        * `ipv6` format
        * `duration` format
    * `minLength`, `maxLength` fields - string length chosen randomly between these values
* `integer` type
    * `minimum`, `maximum` fields - a random integer value chosen randomly between these values
    * `exclusiveMinimuim` field (boolean, JSON-Schema 4)
    * `exclusiveMaximum` field (boolean, JSON-Schema 4)
    * `multipleOf` field
* `number` type
    * `minimum`, `maximum` fields - a random float value chosen randomly between these values
    * `exclusiveMinimuim` field (boolean, JSON-Schema 4)
    * `exclusiveMaximum` field (boolean, JSON-Schema 4)
    * `multipleOf` field