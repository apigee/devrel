# Apigee Sackmesser

<!-- markdownlint-disable-next-line MD013 MD033 -->
<img src="./img/sackmesser-logo.png" alt="sackmesser-logo" width="200" align="right" >

> :blue_book: **Sack·mes·ser**: from the German words "Sack" *pocket* and
"Messer" *knife* is the Swiss German name for the famous multi-tool that
is used by adventurers in a variety of practical situations.

Apigee Sackmesser is a collection of tools that provide a unifying experience
for interacting with the Apigee Management APIs for Apigee X/hybrid and Edge.
It also lets you deploy API proxies, shared flows and configuration to both
stacks without writing any additional manifest files.

**Please note that for Apigee Private Cloud (OPDK), Sackmesser only supports `list`, `export`, and `report` operations at this time.
Support for other operations will be added soon.
For Apigee Private Cloud (OPDK), apart from providing details for Proxies and SharedFlows, Sackmesser `report` also provides details about Apigee Environment Configurations (Key Value Maps, Keystores, Target Servers, Flow Hooks, References, Virtual Hosts, and Caches) and Apigee Organization Configurations (API Products, Developers, and Developer Apps).**

For interacting with the management API of Apigee X/hybrid only (without the
need for backwards compatibility for Apigee Edge) you can also try the [apigeecli](https://github.com/apigee/apigeecli)
commandline utility.

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
await
clean
deploy
export
help
list
report

Options:
--googleapi (default), use apigee.googleapis.com (for X, hybrid)
--apigeeapi, use api.enterprise.apigee.com (for Edge); also set this flag if you are using Apigee Private Cloud (OPDK)
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
--debug, show verbose debug output
--deployment-sa, GCP Service Account to associate with the deployment (X,hybrid only)
--description, Human friendly proxy or shared flow description
--insecure, set this flag if you are using Apigee Private Cloud (OPDK) and http endpoint for Management API
--opdk, set this flag if you are using Apigee Private Cloud (OPDK)
--skip-config, Skip configuration in org export
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

### Scenario: Deploy a proxy bundle

The **deploy** command lets you deploy proxies, shared flows and configurations.

Example: Deploy a proxy straight from Github to Apigee X / hybrid

```sh
sackmesser deploy -g https://github.com/apigee/devrel/tree/main/references/cicd-pipeline \
--googleapi \
-t "$TOKEN" \
-o "$APIGEE_X_ORG" \
-e "$APIGEE_X_ENV" \
-b "/airports/v1"
```

Example: Deploy a proxy from the local file system to Apigee Edge

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

The **export** command lets you export proxies and configuration to the local
file system. The resources can be used for analysis and/or to be re-deployed
via the deploy command.

```sh
# Apigee X/hybrid
sackmesser export --googleapi -o "$APIGEE_X_ORG" -t "$APIGEE_TOKEN"

# Apigee Edge
sackmesser export --apigeeapi -o "$APIGEE_ORG" -u "$APIGEE_USER" -p "$APIGEE_PASS"

# Apigee Private Cloud (OPDK) - Secure (with HTTPS); use `-e "$APIGEE_ENV"` to have Apigee Environment specific export
sackmesser export --apigeeapi -o "$APIGEE_ORG" -u "$APIGEE_USER" -p "$APIGEE_PASS" --opdk --baseuri "$MANAGEMENT_SERVER_HTTPS_URL"

# Apigee Private Cloud (OPDK) - Insecure (without HTTPS); use `-e "$APIGEE_ENV"` to have Apigee Environment specific export
sackmesser export --apigeeapi -o "$APIGEE_ORG" -u "$APIGEE_USER" -p "$APIGEE_PASS" --opdk --baseuri "$MANAGEMENT_SERVER_IP:$MANAGEMENT_SERVER_PORT" --insecure
```

### Scenario: List all deployments in a specific org and environment

The **list** command is a helper function around the Apigee management API
to list resources in an Apigee organization.

```sh
# Apigee X/hybrid
sackmesser list --googleapi -t "$APIGEE_TOKEN" organizations/$APIGEE_X_ORG/environments/$APIGEE_X_ENV/deployments

# Apigee Edge
sackmesser list --apigeeapi -u "$APIGEE_USER" -p "$APIGEE_PASS" organizations/$APIGEE_ORG/environments/$APIGEE_ENV/deployments

# Apigee Private Cloud (OPDK) - Secure (with HTTPS)
sackmesser list --apigeeapi -u "$APIGEE_USER" -p "$APIGEE_PASS" organizations/$APIGEE_ORG/environments/$APIGEE_ENV/deployments --opdk --baseuri "$MANAGEMENT_SERVER_HTTPS_URL"

# Apigee Private Cloud (OPDK) - Insecure (without HTTPS)
sackmesser list --apigeeapi -u "$APIGEE_USER" -p "$APIGEE_PASS" organizations/$APIGEE_ORG/environments/$APIGEE_ENV/deployments --opdk --baseuri "$MANAGEMENT_SERVER_IP:$MANAGEMENT_SERVER_PORT" --insecure

```

### Scenario: Clean up all proxies in a specific org

The **clean** command can be used to delete individual resources e.g proxies or
developers from an Apigee organization.

```sh
# Apigee X/hybrid
sackmesser clean --googleapi -t "$APIGEE_TOKEN" -o "$APIGEE_X_ORG" proxy all
sackmesser clean developer "janedoe@example.com" --googleapi -t "$APIGEE_TOKEN" -o "$APIGEE_X_ORG"

# Apigee Edge
sackmesser clean --apigeeapi -u "$APIGEE_USER" -p "$APIGEE_PASS" proxy all
sackmesser clean developer "janedoe@example.com" --apigeeapi -u "$APIGEE_USER" -p "$APIGEE_PASS"
```

### Scenario: Create a Report of Deployments in an Environment

The **report** command can be used to create an HTML report that shows the
usage of Apigee features and their compliance with best practices
within an environment.

```sh
# Apigee X/hybrid
sackmesser report --googleapi -t "$TOKEN" -o "$APIGEE_X_ORG" -e "$APIGEE_X_ENV"

# Apigee Edge
sackmesser report --apigeeapi -u "$APIGEE_USER" -p "$APIGEE_PASS" -o "$APIGEE_ORG" -e "$APIGEE_ENV"

# Apigee Private Cloud (OPDK) - Secure (with HTTPS)
sackmesser report --apigeeapi -u "$APIGEE_USER" -p "$APIGEE_PASS" -o "$APIGEE_ORG" -e "$APIGEE_ENV" --opdk --baseuri "$MANAGEMENT_SERVER_HTTPS_URL"

# Apigee Private Cloud (OPDK) - Insecure (without HTTPS)
sackmesser report --apigeeapi -u "$APIGEE_USER" -p "$APIGEE_PASS" -o "$APIGEE_ORG" -e "$APIGEE_ENV" --opdk --baseuri "$MANAGEMENT_SERVER_IP:$MANAGEMENT_SERVER_PORT" --insecure
```

## How does this compare to the Apigee Maven Plugin and other Apigee tooling

The Apigee Sackmesser is implemented as a wrapper for the Apigee Maven
that simplifies Apigee deployments by eliminating the need for you to create and
maintain pom files. It supports proxy deployments to Apigee Edge, hybrid and X
products. It also provides a Docker container that removes the need for you to
install Java and Maven and its dependencies on your build machines with m2 cache
initialized at the time of docker build.
