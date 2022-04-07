# Configurable Proxy Generator from OAS

This tool generates configurable proxy archives from OpenAPI Specifications.

It includes the following features:
* Creates the configurable proxy operations based on the OAS paths
* API Key validation at a global or operation level
* Configurable base path (using the OPTIONAL `--basepath` flag)
* Target Server based on the hostname
* Environment deployment registration (using the OPTIONAL `--envs` flag)

## Getting started

We start by defining the following variables dependent on your installation:

```
APIGEE_ARCHIVE_ENV=my-env # Apigee Environment of type archive
APIGEE_ORG=my-org
APIGEE_HOSTNAME=https://my-hostname.com
```

From within the root folder run:

```sh
npm install
```

to install the dependencies and run:

```sh
npm start --  --oas=./test/oas/apigeemock-v3.yaml --basepath /mock/v3 --name apigeemock-v3
```

To see the proxy config printed to stdout. If you add an output folder
with the `--out` flag then the archive will be created or augmented in the
specified folder

```sh
npm start -- --oas=./test/oas/apigeemock-v3.yaml --basepath /mock/v3 --name apigeemock-v3 --out ./my-archive --envs $APIGEE_ARCHIVE_ENV
npm start -- --oas=./test/oas/apigeemock-v2.yaml --basepath /mock/v3 --name apigeemock-v2 --out ./my-archive --envs $APIGEE_ARCHIVE_ENV
```

To deploy the archive to your Apigee runtime you can run the following command:

```sh
gcloud alpha apigee archives deploy --organization=$APIGEE_ORG --environment=$APIGEE_ARCHIVE_ENV --source=./my-archive
```

Once the deployment is successful, you can try it using:

```sh
curl $APIGEE_HOSTNAME/mock/v2/json
```