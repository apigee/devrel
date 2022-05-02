# Apigee Templater
A tool for automating the templating of Apigee API proxies through either a **CLI**, **REST API**, or **Typescript/Javascript** module. The generated proxy can either be downloaded as a bundle, or deployed directly to an Apigee X environment.  

You can try out the tool easily in Google Cloud Shell including a tutorial walk-through of the features by clicking here:

[![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.png)](https://ssh.cloud.google.com/cloudshell/open?cloudshell_git_repo=https://github.com/tyayers/devrel&cloudshell_git_branch=main&cloudshell_workspace=.&cloudshell_tutorial=tools/apigee-templater/docs/cloudshell-tutorial.md)

## Prerequisites
This tool assumes you already have an Apigee X org and environment provisioned (either production or eval, see [here](https://cloud.google.com/apigee/docs/api-platform/get-started/provisioning-intro) for more info).  Also you should have **gcloud** installed and the project set to where Apigee X is provisioned.

## TLDR;

### Proxy a web endpoint

Just run this command to deploy a sample test proxy to your Apigee X **eval** environment (or change to any environment) in your current project.

```sh
# Install CLI globally and use a simple template to create a proxy
npm install -g apigee-templater-cli
apigee-template -n HttpBinProxy -b /httpbin -t https://httpbin.org -d -e eval
# OR just run using npx
npx apigee-templater-cli -n HttpBinProxy -b /httpbin -t https://httpbin.org -d -e eval
```
Output:
```sh
# Proxy bundle was generated and deployed to environment "eval"
> Proxy HttpBinProxy generated to ./HttpBinProxy.zip in 32 milliseconds.
> Proxy HttpBinProxy version 1 deployed to environment eval in 2258 milliseconds.
> Wait 2-3 minutes, then test here: https://eval-group.34-111-104-118.nip.io/httpbin
```

### Proxy a BigQuery data table

Run this command to build and deploy a proxy to the **Austin Bike Sharing Trips public dataset** and access that data (including filters, paging and sorting) through a REST API.

```sh
# Build proxy to BigQuery table using globally installed CLI
apigee-template -n BikeTrips-v1 -b /trips -q bigquery-public-data.austin_bikeshare.bikeshare_trips -d -e eval -s serviceaccount@project.iam.gserviceaccount.com
# OR run with npx without installing CLI
npx apigee-templater-cli -n BikeTrips-v1 -b /trips -q bigquery-public-data.austin_bikeshare.bikeshare_trips -d -e eval -s serviceaccount@project.iam.gserviceaccount.com
```

Output:
```sh
# Proxy bundle was generated and deployed to environment "eval" with service identity
> Proxy BikeTrips-v1 generated to ./BikeTrips-v1.zip in 42 milliseconds.
> Proxy BikeTrips-v1 version 1 deployed to environment eval in 3267 milliseconds.
> Wait 2-3 minutes, then test here: https://eval-group.34-111-104-118.nip.io/trips
```
After waiting a few minutes, you can run **curl https://eval-group.34-111-104-118.nip.io/trips?pageSize=1** and get bike trip data returned, with URL parameters **pageSize**, **filter**, **orderBy** and **pageToken**.

```sh
{
  "trips": [
    {
      "trip_id": "9900289692",
      "subscriber_type": "Walk Up",
      "bikeid": "248",
      "start_time": "1.443820321E9",
      "start_station_id": "1006",
      "start_station_name": "Zilker Park West",
      "end_station_id": "1008",
      "end_station_name": "Nueces @ 3rd",
      "duration_minutes": "39"
    }
  ],
  "next_page_token": 2
}
```

Check out the deployed proxies in the [Apigee console](https://apigee.google.com), where you can check the status of the deployments, do tracing, and create API products based on these automated proxies.

## Features

The module & CLI can generate and deploy Apigee X proxies with these features out-of-the-box, and can be extended with new features easily (see "Extending & Customizing" section below).

* Proxy name
* Base path
* Targets
  * HTTPS Urls
  * BigQuery Queries
  * BigQuery Tables
* Auth with apikey or 3rd party OAuth token
* Quotas
* Spike Arrests

The templating engine uses the [Handlebars](https://handlebarsjs.com/) framework to build any type of proxy based on structured inputs.  And because the logic is contained in Javascript or Typescript plugins, logic can be added for any type of requirement.

## Getting Started

### CLI
Install the CLI like this.
```bash
npm install -g apigee-templater-cli
```
Or use the CLI without installing.
```bash
npx apigee-templater-cli
```

Before calling the CLI, make sure you have a user and project set in your environment.  These are used to authenticate to the Apigee X API for deployments (if you are not deploying, then you don't need this).  The default application user can be set with **gcloud auth application-default login** and the default project set with **gcloud config set project PROJECT**.

Use the CLI either in command or interactive mode.
```bash
#Use the CLI in interactive mode to collect inputs
apigee-template
> Welcome to apigee-template, use -h for more command line options. 
? What should the proxy be called? MyProxy
? Which base path should be used? /test
? Which backend target should be called? https://test.com
? Do you want to deploy the proxy to an Apigee X environment? No
> Proxy MyProxy generated to ./MyProxy.zip in 60 milliseconds.
```
```bash
#Show all commands
apigee-template -h
```
```bash
#Generate a proxy based on input.json and deploy it to environment test1 with credentials in key.json
apigee-template -f ./samples/input.json -d -e test1
```
```bash
#Generate a proxy that creates an API to a BigQuery table, including the raw data-to-REST mapping logic, and deploy it to the Apigee X environment eval with the service account (for authenticating to BigQuery)
apigee-template -n BikeTrips-v1 -b /trips -q bigquery-public-data.austin_bikeshare.bikeshare_trips -d -e eval -s serviceaccount@project@project.iam.gserviceaccount.com
```
### REST API
You can run the REST API service locally or deploy to any container runtime environment like [Cloud Run](https://cloud.google.com/run) (default deployment requires unauthenticated access).  

[![Run on Google Cloud](https://deploy.cloud.run/button.svg)](https://deploy.cloud.run)

After deploying you can call the API like this (to generate and download a proxy bundle).

```bash
curl --location --request POST 'http://localhost:8080/apigeegen/file' \
--header 'Content-Type: application/json' \
--data-raw '{
  "name": "testproxy",
  "proxyType": "programmable",
  "endpoints": [
    {
      "name": "default",
      "basePath": "/httpbin",
      "target": {
        "name": "default",
        "url": "https://httpbin.org"
      },
      "auth": [
        {
          "type": "apikey"
        }
      ],
      "quotas": [
        {
          "count": 30,
          "timeUnit": "minute"
        }
      ],
      "spikeArrest": {
        "rate": "30s"
      }
    }
  ]
}'
```
A **test web frontend of the REST API** can be tested [here](https://apigee-templater-h7pi7igbcq-ew.a.run.app/).

### Typescript/Javascript
First install and import into your project.
```bash
npm install apigee-templater-module
```
Then use the generator module to build proxies.

```ts
import {ApigeeTemplateInput, ApigeeGenerator, proxyTypes, authTypes} from 'apigee-templater-module'

apigeeTemplater: ApigeeGenerator = new ApigeeGenerator(); // Optionally custom conversion plugins can be passed here, defaults are included.

let input: ApigeeTemplateInput = {
  name: "MyProxy",
  type: proxyTypes.programmable,
  endpoints: [
    {
      name: "default",
      basePath: "/myproxy",
      target: {
        name: "default",
        url: "https://httpbin.org"
      },
      quotas: [
        {
          count: 200,
          timeUnit: "day"
        }
      ],
      auth: [
        {
          type: authTypes.apikey
        }
      ]
    }
  ]
}

apigeeGenerator.generateProxy(input, "./proxies").then((result) => {
  // Proxy bundle generated to ./proxies/MyProxy.zip
  console.log(`Proxy successfully generated to ${result.localPath}!`);
});

```

## Extending & Customizing the Templates
The project is designed to be extensible.  You can extend or customize in 2 ways.

### 1. Create your own cli or service project
This option requires you to change the host CLI or service process to inject your own plugins in the ApigeeGenerator constructor.  You can see how the **cli** and **service** projects do this when they create the object.

```typescript
  // Pass an array of template and input converter plugins that are used at runtime.
  apigeeGenerator: ApigeeTemplateService = new ApigeeGenerator([
    new SpikeArrestPlugin(),
    new AuthApiKeyPlugin(),
    new AuthSfPlugin(),
    new QuotaPlugin(),
    new TargetsPlugin(),
    new ProxiesPlugin(),
  ], [
    new Json1Converter(),
    new Json2Converter(),
    new OpenApiV3Converter()
  ]);
```
The above plugins are delivered in the **apigee-templater-module** package, but you can easily write your own by implementing the **ApigeeTemplatePlugin** interface (see /module/lib/plugins for examples).

### 2. Add a script callout when using the CLI
The second option is to add a script using the **-s** parameter when calling the **apigee-template** CLI.  This script is evaluated before the templating is done, and can make changes to the **ApigeeGenerator** object as needed, by for example removing, replacing or adding plugins for both templating and input conversion.

```bash
# Create a proxy based on ./samples/input.json using customization script ./samples/script.js,
# which replaces the generic **QuotaPlugin** with a developer-specific **DevQuotaPlugin**
apigee-template -f ./samples/input.json -s ./samples/script.js
```

## Feedback and feature requests
In case you find this useful feel free to request features or report bugs as Github issues.
