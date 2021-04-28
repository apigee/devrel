# Apigee Sackmesser

The Apigee Sackmesser lets you deploy API proxies, shared flows and
configuration to Apigee Edge as well as hybrid/X without writing any additional
manifest files.

Sackmesser can be used either as a commandline tool or a Docker
container. To use it as a CLI you sould add it to your path:

```sh
PATH="$PATH:$PWD/bin"
```

To use it as a Docker container you can build the image:

```sh
build.sh -t apigee-sackmesser
```

## Deploy Command

```sh
$ sackmesser deploy -h

usage: sackmesser deploy -e ENV -o ORG [--googleapi | --apigeeapi] [-t TOKEN | -u USER -p PASSWORD] [options]

Apigee deployment utility

Options:
--googleapi (default), use apigee.googleapi.com (for X, hybrid)
--apigeeapi, use api.enterprise.apigee.com (for Edge)
-b,--base-path, overrides the default base path for the API proxy
-d,--directory, path to the apiproxy folder to be deployed
-e,--environment, Apigee environment name
-g,--github, Link to proxy bundle on github
-n,--api, Overrides the default API proxy name
-o,--organization, Apigee organization name
-u,--username, Apigee User Name (Edge only)
-p,--password, Apigee User Password (Edge only)
-m,--mfa, Apigee MFA code (Edge only)
-t,--token, GCP token (X,hybrid only) or OAuth2 token (Edge)
--description, Human friendly proxy description
```

## CLI Examples

### Scenario: Deploy a proxy straight from Github to Apigee X / hybrid

```sh
sackmesser deploy -g https://github.com/apigee/devrel/tree/main/references/cicd-pipeline \
--googleapi \
-t "$TOKEN" \
-o "$APIGEE_X_ORG" \
-e "$APIGEE_X_ENV" \
-b "/airports/v1"
```

### Scenario: Deploy a proxy from the local machine to Apigee Edge

```sh
MFA=<MFA token goes here>

sackmesser deploy -d "$PWD/../../references/cicd-pipeline" \
--apigeeapi \
--description "deployment from local folder" \
-n test-cicd-v0 \
-b "/airports/test-v1" \
-u "$APIGEE_USER" \
-p "$APIGEE_PASS" \
-m "$MFA" \
-o "$APIGEE_ORG" \
-e "$APIGEE_ENV"
```

## Docker Examples

### Scenario: Deploy a proxy straight from Github to Apigee X / hybrid

```sh
docker run apigee-sackmesser deploy \
--googleapi \
-g https://github.com/apigee/devrel/tree/main/references/cicd-pipeline \
-t "$TOKEN" \
-o "$APIGEE_X_ORG" \
-e "$APIGEE_X_ENV" \
-b "/airports/v1"
```

### Scenario: Deploy a proxy from the local machine to Apigee Edge

```sh
docker run -v $PWD/../../references/cicd-pipeline/apiproxy:/opt/apigee/apiproxy \
apigee-sackmesser deploy \
--apigeeapi \
-n test-cicd-v0 \
-b "/airports/test-v1" \
-u "$APIGEE_USER" \
-p "$APIGEE_PASS" \
-o "$APIGEE_ORG" \
-e "$APIGEE_ENV"
```

## How does this compare to the Apigee Maven Plugin and other Apigee tooling

The Apigee Sackmesser is implemented as a wrapper for the Apigee Maven
that simplifies Apigee deployments by eliminating the need for you to create and
maintain pom files. It supports proxy deployments to Apigee Edge, hybrid and X
products. It also provides a Docker container that removes the need for you to
install Java and Maven and its dependencies on your build machines with m2 cache
initialised at the time of docker build.
