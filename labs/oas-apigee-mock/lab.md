id: oas-apigee-mock

# OAS Apigee Mock Lab

## Overview

Duration: 0:02:00

This lab walks through the process of generating, deploying and testing a mock
proxy on Apigee X.
The lab focuses on leveraging useful tools and best practices, with some
practical examples. Over the course of the lab you will step through
the process shown below. An Open API specification and test suite have already
been provided for the lab. You can use these as a reference
to leverge this same process in your own API development work.

![Overview](assets/overview.png)

We assume the basic knowledge of the Apigee platform and you will get the most
from this lab if you already have this knowledge.

Ideally you will have completed the Apigee courses on
[Design](https://www.coursera.org/learn/api-design-apigee-gcp),
[Development](https://www.coursera.org/learn/api-development-apigee-gcp) and
[Security](https://www.coursera.org/learn/api-security-apigee-gcp) Courses.
These are available through Coursera, Pluralsight or Qwiklabs.

Alternatively, completing the Apigee
[API Jam](https://github.com/apigee/apijam) will cover the same topics in
less depth.

Lets get started!

## Prerequisites

Duration: 0:30:00

An Apigee X organisation configured for external exposure is required to
complete this lab. See
[here](https://github.com/apigee/devrel/tree/main/tools/apigee-x-trial-provision)
for details on provisioning an evaluation organisation.

### Tools

You will need to have the following dependencies configired in you local
enviornment in order to complete the lab tasks:

- Bash (Unix shell)
- [NodeJS](https://nodejs.org/en/) LTS version or above.
- [gcloud](https://cloud.google.com/sdk/docs/install)
- [git](https://git-scm.com/)
- [apigee-sackmesser](https://github.com/apigee/devrel/tree/main/tools/apigee-sackmesser)
- [apigeecli](https://github.com/srinandan/apigeecli)
- [jq](https://stedolan.github.io/jq/)

### Environment Variables

Commands used during the lab will require the following environment variables
to be configured.

``` bash
export TOKEN=$(gcloud auth application-default print-access-token)
export APIGEE_ENV=<apigee-environment-name>
export APIGEE_ORG=<gcp-project-name>
export RUNTIME_HOST_ALIAS=<your-runtime-host-alias>
```

### oas-apigee-mock

Clone the Apigee DevRel repo and install the dependencies for the
oas-apigee-mock tool.

``` bash
git clone https://github.com/apigee/devrel.git
cd devrel/tools/oas-apigee-mock/
npm install
```

## Generate, deploy and test an Apigee Proxy

Duration: 0:30:00

### Generate an Apigee Proxy from an Open API Specification

Use the `orders-apikey-header.yaml` Open API specification included
in the `devrel/tools/oas-apigee-mock/test/oas` folder to generate a proxy bundle.

``` bash
node bin/oas-apigee-mock generateApi web-orders-proxy-v1 \
  -s test/oas/orders-apikey-header.yaml \
  -o
```

### Update the apickli configuration to use your Host Alias

Update the `before(function ()` block in
`test/features/step_definitions/init.js` with your organisation's hostname.
This will be your `RUNTIME_HOST_ALIAS` if you followed the
[Apigee X Trial Provisioning](https://github.com/apigee/devrel/tree/main/tools/apigee-x-trial-provision)
script.

``` javascript
before(function () {
  this.apickli = new apickli.Apickli(
    "https",process.env.RUNTIME_HOST_ALIAS
  );
```

### Update the test suite proxy reference

Update the test suite with your proxy name, we used `web-orders-proxy-v1` in
the generate proxy step.

``` bash
sed -i 's/oas-apigee-mock-orders-apikey-header/web-orders-proxy-v1/' test/features/orders-apikey-header.feature
```

### Test the Proxy

Lets start testing by runing the test suite.

``` bash
./node_modules/.bin/cucumber-js test/features/orders-apikey-header.feature --format json:test/test_report.json --publish-quiet
```

The test should fail as we have yet to deploy the proxy we generated
previously.

### Deploy the generated proxy to your Apigee Organisation

``` bash
sackmesser deploy -d "$PWD/api_bundles/web-orders-proxy-v1" --googleapi -t "$TOKEN" -o "$APIGEE_ORG" -e "$APIGEE_ENV"
```

### Start debugging

Turn on [debug](https://cloud.google.com/apigee/docs/api-platform/debug/trace)
and run the test suite again.

``` bash
./node_modules/.bin/cucumber-js test/features/orders-apikey-header.feature --format json:test/test_report.json --publish-quiet
```

Once again the tests should fail but for a different reason. Use the Apigee
debug tool to investigate the cause.

### Create an  API Product, Developer and App

The generated proxy is protected by a Verify API Key policy (as specificied
in the Open API Specification used), a valid API Key is needed in order to
sucessfully make API calls to the proxy. To obtain an API Key we need to
create an API product which includes our proxy and register a developer and
application which will use that API Product.

``` bash
apigeecli products create -t "$TOKEN" -o "$APIGEE_ORG" --name "web-orders" --proxies "web-orders-proxy-v1" --envs "$APIGEE_ENV" --approval "auto"
apigeecli devs create -t "$TOKEN" -o "$APIGEE_ORG" --email "web-orders@example.com" --user "web-orders@example.com" --first "Web" --last "Developer"
apigeecli apps create -t "$TOKEN" -o "$APIGEE_ORG" --email "web-orders@example.com" --prods "web-orders" --name "web-orders-app" > app.json

APIKEY=$(jq '.credentials[0].consumerKey' -r < app.json )
export APIKEY
echo "APIKEY is $APIKEY"
```

### Retest the Proxy

A valid API Key is now available as an environment variable and can now be
used by the test suite.
Turn on [debug](https://cloud.google.com/apigee/docs/api-platform/debug/trace)
again, run the test suite and verify the tests are now passing.

``` bash
./node_modules/.bin/cucumber-js test/features/orders-apikey-header.feature --format json:test/test_report.json --publish-quiet
```

## Summary

You have sucessfully generated, deployed and tested a mock
proxy on Apigee X.

![Overview](assets/overview.png)
