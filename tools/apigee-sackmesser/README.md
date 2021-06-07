# Apigee Sackmesser

<!-- markdownlint-disable-next-line MD013 MD033 -->
<img src="./img/sackmesser-logo.png" alt="sackmesser-logo" width="200" align="right" >

The Apigee Sackmesser lets you deploy API proxies, shared flows and
configuration to Apigee Edge as well as hybrid/X without writing any additional
manifest files.

Please note that Apigee Private Cloud (OPDK) is not yet supported at this time.

Sackmesser can be used either as a commandline tool or a Docker
container. To use it as a CLI you can add it to your path:

```sh
PATH="$PATH:$PWD/bin"
```

To use it as a Docker container you can build the image:

```sh
./build.sh -t apigee-sackmesser
```

## General Usage

```text
$ sackmesser help

usage: sackmesser COMMAND -e ENV -o ORG [--googleapi | --apigeeapi] [-t TOKEN | -u USER -p PASSWORD] [options]

Apigee Sackmesser utility.

Commands:
deploy
list
export
help
clean

Options:
--googleapi (default), use apigee.googleapis.com (for X, hybrid)
--apigeeapi, use api.enterprise.apigee.com (for Edge)
-b,--base-path, overrides the default base path for the API proxy
-d,--directory, path to the apiproxy or shared flow bundle to be deployed
-e,--environment, Apigee environment name
-g,--github, Link to proxy or shared flow bundle on github
-h,--hostname, publicly reachable hostname for the environment
-L,--baseuri, override default baseuri for the Management API / Apigee API
-m,--mfa, Apigee MFA code (Edge only)
-n,--name, Overrides the default API proxy or shared flow name
-o,--organization, Apigee organization name
-p,--password, Apigee User Password (Edge only)
-t,--token, GCP token (X,hybrid only) or OAuth2 token (Edge)
-u,--username, Apigee User Name (Edge only)
--async, Asynchronous deployment option (X,hybrid only)
--description, Human friendly proxy or shared flow description
--debug, show verbose debug output
```

## CLI Examples

The following examples show sackmesser commands as a CLI in the form of

```sh
sackmesser COMMAND [...]
```

If you prefer to use the Docker container you can use the same `COMMAND [...]`
with the following prefix (note that the deploy command needs a volume
mount to refer to local directories):

```sh
docker run -v "$PWD":/opt/apigee apigee-sackmesser COMMAND [...]
```

### Scenario: Deploy a proxy straight from Github to Apigee X / hybrid

```sh
sackmesser deploy -g https://github.com/apigee/devrel/tree/main/references/cicd-pipeline \
--googleapi \
-t "$TOKEN" \
-o "$APIGEE_X_ORG" \
-e "$APIGEE_X_ENV" \
-b "/airports/v1"
```

### Scenario: Deploy a proxy from the local file system to Apigee Edge

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

### Scenario: Export all resources of a specific org

```sh
# Apigee X/hybrid
sackmesser export --googleapi -o "$APIGEE_X_ORG" -t "$APIGEE_TOKEN"

# Apigee Edge
sackmesser export --apigeeapi -o "$APIGEE_ORG" -u "$APIGEE_USER" -p "$APIGEE_PASS"
```

### Scenario: List all deployments in a specific org and environment

```sh
# Apigee X/hybrid
sackmesser list --googleapi -t "$APIGEE_TOKEN" organizations/$APIGEE_X_ORG/environments/$APIGEE_X_ENV/deployments

# Apigee Edge
sackmesser list --apigeeapi -u "$APIGEE_USER" -p "$APIGEE_PASS" organizations/$APIGEE_ORG/environments/$APIGEE_ENV/deployments
```

### Scenario: Clean up all proxies in a specific org

```sh
# Apigee X/hybrid
sackmesser clean --googleapi -t "$APIGEE_TOKEN" proxy all

# Apigee Edge
sackmesser clean --apigeeapi -u "$APIGEE_USER" -p "$APIGEE_PASS" proxy all
```

## How does this compare to the Apigee Maven Plugin and other Apigee tooling

The Apigee Sackmesser is implemented as a wrapper for the Apigee Maven
that simplifies Apigee deployments by eliminating the need for you to create and
maintain pom files. It supports proxy deployments to Apigee Edge, hybrid and X
products. It also provides a Docker container that removes the need for you to
install Java and Maven and its dependencies on your build machines with m2 cache
initialised at the time of docker build.
