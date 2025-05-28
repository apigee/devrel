# Migrate Apigee Edge to X

Self service migration from Apigee Edge to Apigee X.

This is a set of tools, scripts and code to export Apigee Edge data,
convert to Apigee X format, and import into Apigee X.

Importing proxies and sharedflows will succeed if they do not use
unsupported policies or features in X. The import tool (apigeecli)
will show details of what policies and features are not supported.

Importing Developers requires emails to be lower case. This may be
an issue as Apigee Edge emails are case sensitive, meaning that
"CaseSensitive@any.com" and "casesensitive@any.com" are different
developers in Edge but they will be the same in X.

Importing Developers and Apps copies the credentials (API key and secret).

This is not a turnkey solution, tools and scripts are run manually step-by-step.
It requires manual intervention when errors occur importing proxies,
shared flows, apps and developers.

Migration Steps Flow:

1. Export from Edge using [apigee-migrate-tool](https://github.com/apigeecs/apigee-migrate-tool)
and [Edge API](https://apidocs.apigee.com/apis)  (writes to $EDGE_EXPORT_DIR)
2. Convert Edge data to X format using bash and python (writes to $X_IMPORT_DIR)
3. Import to X using [apigeecli](https://github.com/apigee/apigeecli)
(reads from $X_IMPORT_DIR)

# Coverage

- [ ] Org level 
  - [x] Proxies 
  - [x] Sharedflows 
  - [x] KVMs 
    - [x] Export encrypted entries only with kvm helper proxy
    (see https://github.com/kurtkanaskie/apigee-edge-facade-v1)
  - [x] Developers 
  - [x] API Products 
  - [x] Apps and keys 
  - [ ] Companies, Company Developers and Company Apps - need to
  convert to AppGroups
  - [ ] Reports 
- [ ] Env level 
  - [x] Target Servers except those with mTLS
     - [ ] Keystores, Truststores 
  - [x] KVMs 
     - [x] Encrypted entries only with kvm helper proxy
     (see https://github.com/kurtkanaskie/apigee-edge-facade-v1)
- [x] Proxy level
  - [x] KVMs 
     - [x] Encrypted entries only with modifications to proxy
     to retrieve encrypted values vai KVM policy.
- [x] Runtime
  - [x] OAuth access and refresh token adoption
  (see https://github.com/kurtkanaskie/edge-to-X-oauth-token-migration)

# Background

[Differences between Apigee Edge and Apigee X](https://docs.apigee.com/migration-to-x/compare-apigee-edge-to-apigee-x?hl=en)\
[Apigee Edge to Apigee X migration antipatterns](https://docs.apigee.com/migration-to-x/migration-antipatterns)

# Dependencies

Export from Edge 
- [apigee-migrate-tool](https://github.com/apigeecs/apigee-migrate-tool) 
  - npm, node, grunt 
- [Edge API](https://apidocs.apigee.com/apis) 
  - [get\_token, acurl](https://docs.apigee.com/api-platform/system-administration/auth-tools)
  or user credentials without 2 factor authentication 

Convert to X format
  - Custom [Python3](https://www.python.org/) scripts

Import to X
  - [apigeecli](https://github.com/apigee/apigeecli) (v2.12.1 or greater due to KVM import issue)
  - [Apigee API](https://cloud.google.com/apigee/docs/reference/apis/apigee/rest)
    - [gcloud](https://cloud.google.com/sdk/gcloud)

Miscellaneous
  - curl, git, jq, tree

# Set up and Environment Variables
Consider using [glcoud config](https://cloud.google.com/sdk/gcloud/reference/config)
to create a configurations for your Apigee X orgs to easily switch between them.

## Set up
Create a working directory (e.g. mkdir $HOME/edge-to-x-migration-devrel) and cd there.\
Clone [devrel](https://github.com/apigee/devrel.git) (this repository)
Clone and install [apigee-migrate-tool](https://github.com/apigeecs/apigee-migrate-tool).\
Install [python3](https://www.python.org/downloads/), apigeecli and any other required tools.

```bash
# Create a working directory
export EDGE_X_MIGRATION_DIR=$HOME/edge-to-x-migration-devrel
mkdir -p $EDGE_X_MIGRATION_DIR
cd $EDGE_X_MIGRATION_DIR

# Clone devrel (this repo)
git clone https://github.com/apigee/devrel.git

# Install apigee-migrate tool
git clone https://github.com/apigeecs/apigee-migrate-tool.git
cd apigee-migrate-tool
npm install
grunt --version
grunt-cli v1.5.0
grunt v1.6.1

# Install Python3
python3 --version
Python 3.11.5

# Install https://github.com/apigee/apigeecli
curl -L https://raw.githubusercontent.com/apigee/apigeecli/main/downloadLatest.sh | sh -
apigeecli -v
apigeecli version 2.11.0 date: 2025-03-31T20:08:55Z [commit: 95cc9d1]
```

## Set Environment Variables
Copy the `set_env_example.sh` file to `set_env.sh` and edit to use your values,
then use `source set_env.sh` to set the environment variables.

Specify your top level working directory: EDGE_X_MIGRATION_DIR\
Specify your values for Apigee Edge: EDGE_ORG and ENVS\
Specify your values for Apigee X: X_ORG\
The rest can be left as they are.

```bash
cp devrel/tools/apigee-edge-to-x-migration/set_env_example.sh set_env.sh
```

```bash
export EDGE_X_MIGRATION_DIR=$HOME/edge-to-x-migration-devrel
export EDGE_ORG=your_edge_org_name
export ENVS="env1 env2"
export B64UNPW="base64 of your_username:your_password"
export EDGE_AUTH="Authorization: Basic $B64UNPW"

export EDGE_EXPORT_DIR=$EDGE_X_MIGRATION_DIR/edge-export
mkdir $EDGE_EXPORT_DIR
export EXPORTED_ORG_DIR=$EDGE_EXPORT_DIR/data-org-${EDGE_ORG}

export X_ORG=your_x_org_name
export X_IMPORT_DIR=$EDGE_X_MIGRATION_DIR/x-import
mkdir $X_IMPORT_DIR

export APIGEE_MIGRATE_EDGE_TO_X_TOOLS_DIR=$EDGE_X_MIGRATION_DIR/devrel/tools/apigee-migrate-edge-to-x-tools
export APIGEE_MIGRATE_TOOL_DIR=$EDGE_X_MIGRATION_DIR/apigee-migrate-tool
```

Source the environment variables
```bash
source ./set_env.sh
```

## Set Edge Authorization
Specify your username and password for your machine user or use the
[get_token](https://docs.apigee.com/api-platform/system-administration/using-gettoken) tool.

```bash
# Using a machine user credentials with base64:
B64UNPW=$(echo -n 'username:password' | base64)
export EDGE_AUTH="Authorization: Basic $B64UNPW"

# Using get_token:
export EDGE_TOKEN=$(get_token)
export EDGE_AUTH="Authorization: Bearer $EDGE_TOKEN"

# Verify credentials by getting the response from you Edge org
curl -i -H "$EDGE_AUTH" https://api.enterprise.apigee.com/v1/organizations/$EDGE_ORG
```

# Export from Edge

Uses apigee-migrate-tool and Edge APIs in scripts.

## Set up config.js files
Create `config-$ENV.js` files for each environment using your `userid` and `passwd` values.
Then copy the lowest level env to `config.js` as apigee-migrate-tool only uses that file. 
Don't worry about the `to:` configuration, that is not being used.

Repeat this step for each of the environments being exported.

**NOTE:** apigee-migrate-tool only supports Basic authorization so you’ll need to have a machine user without 2-factor authentication.

```bash
cd $APIGEE_MIGRATE_TOOL_DIR

cat config-test.js
module.exports = {
    from: {
        version: '1',
        url: 'https://api.enterprise.apigee.com',
        userid: 'admin@example.com',
        passwd: 'secret',
        org: 'amer-demo13',
        env: 'test'
    },
    to: {
        version: '1',
        url: 'https://api.enterprise.apigee.com',
        userid: 'me@example.com',
        passwd: 'mypassword',
        org: 'my-new-org',
        env: 'my-new-env'
    }
} ;

cat config-prod.js
module.exports = {
    from: {
        version: '1',
        url: 'https://api.enterprise.apigee.com',
        userid: 'admin@example.com',
        passwd: 'secret',
        org: 'amer-demo13',
        env: 'prod'
    },
    to: {
        version: '1',
        url: 'https://api.enterprise.apigee.com',
        userid: 'me@example.com',
        passwd: 'mypassword',
        org: 'my-new-org',
        env: 'my-new-env'
    }
} ;
```

## Export Resources from Edge
The apigee-migrate-tool outputs data to the `data` directory.

**NOTE:** Since apigee-migrate-tool does not create a sub-directory for envs for target servers or flowhooks, do the extract at the org level and then for each environment separate directories.

**NOTE 2:** exportOrgKVM, exportProxyKVM and exportEnvKVM only work for non-encrypted entries, see https://github.com/kurtkanaskie/apigee-edge-facade-v1 for an alternate solution to export encrypted entries in a format suitable for import using apigeecli.

**NOTE 3:** Ignore the deprecation warnings.

```bash
cd $APIGEE_MIGRATE_TOOL_DIR
cp config-test.js config.js

# Org level
grunt exportProxies
grunt exportSharedFlows
grunt exportReports

grunt exportOrgKVM                       # see NOTE 2 above
# Remove any unwanted KVMs, for example:
rm data/kvm/org/CustomReports${EDGE_ORG}*
rm data/kvm/org/privacy

# Proxy level
grunt exportProxyKVM

mv data $EDGE_EXPORT_DIR/data-org-${EDGE_ORG}

# Env level
for ENV in ${ENVS}; do
    echo ===========================
    echo ENV=$ENV
    cp config-$ENV.js config.js
    grunt exportEnvKVM                   # see NOTE 2 above
    grunt exportTargetServers
    grunt exportFlowHooks

    mv data $EDGE_EXPORT_DIR/data-env-${ENV}
done
```

View the results of the export, for example:

```bash
ls -l $EDGE_EXPORT_DIR
drwxr-xr-x  5 user  primarygroup     160 Sep 20 10:27 data-env-prod
drwxr-xr-x  5 user  primarygroup     160 Sep 20 10:27 data-env-test
drwxr-xr-x  6 user  primarygroup     192 Sep 20 10:13 data-org-amer-demo13
```

```bash
tree $EDGE_EXPORT_DIR
├── apps.json
├── data-env-prod
│   ├── flowhooks
│   │   └── flow_hook_config
│   ├── kvm
│   │   └── env
│   │       └── prod
│   │           ├── GeoIPFilter
│   │           └── GetLogValues
│   └── targetservers
│       ├── oauth-v1
│       └── pingstatus-v1-sharedflows
├── data-env-test
│   ├── flowhooks
│   │   └── flow_hook_config
│   ├── kvm
│   │   └── env
│   │       └── test
│   │           ├── AccessControl
│   │           └── GetLogValues
│   └── targetservers
│       ├── oauth-v1
│       └── pingstatus-v1
└── data-org-amer-demo13
    ├── kvm
    │   ├── org
    │   │   ├── org-config
    │   │   └── org-config-private
    │   └── proxy
    │       ├── kvm-demo
    │       │   └── kvm-demo
    │       └── pingstatus-v1
    │           └── pingstatus-v1-kvm1
    ├── proxies
    │   ├── oauth-v1
    │   └── pingstatus-v1
    ├── reports
    │   ├── 0a5ee23f-1947-4188-8bf5-7beb4007f3fe
    │   └── fe17c0e3-0769-4072-9566-f1b557a4aab5
    └── sharedflows
        ├── AccessControl.zip
        └── GetLogValues.zip

```

# Convert from Edge to X apigeecli format
Reformat the output from apigee-migrate-tool to apigeecli format and move to $X_IMPORT_DIR.

The scripts create-products.sh, create-developers.sh and create-apps.sh use Edge APIs with pagination to extract the entities and convert to apigeecli format.

```bash
cd $X_IMPORT_DIR

##############################################################
# Org Level
# Proxies and Shared Flows

cp -pr $EDGE_EXPORT_DIR/data-org-${EDGE_ORG}/proxies .
cp -pr $EDGE_EXPORT_DIR/data-org-${EDGE_ORG}/sharedflows .

# API Products, Developers, Apps

$APIGEE_MIGRATE_EDGE_TO_X_TOOLS_DIR/create-products.sh
$APIGEE_MIGRATE_EDGE_TO_X_TOOLS_DIR/create-developers.sh
$APIGEE_MIGRATE_EDGE_TO_X_TOOLS_DIR/create-apps.sh

# Org KVMs, Proxy KVMs

$APIGEE_MIGRATE_EDGE_TO_X_TOOLS_DIR/create-org-kvms.sh
$APIGEE_MIGRATE_EDGE_TO_X_TOOLS_DIR/create-proxy-kvms.sh

##############################################################
# Env Level

# KVMs
$APIGEE_MIGRATE_EDGE_TO_X_TOOLS_DIR/create-env-kvms.sh

# Target Servers
$APIGEE_MIGRATE_EDGE_TO_X_TOOLS_DIR/create-targetservers.sh
```

View the results of the conversion, for example:

```bash
ls -l $X_IMPORT_DIR
-rw-r--r--    1 user  primarygroup  176681 Sep 20 10:43 apps.json
-rw-r--r--    1 user  primarygroup   56375 Sep 20 10:43 developers.json
-rw-r--r--    1 user  primarygroup     260 Sep 20 10:44 env__prod__GeoIPFilter__kvmfile__0.json
-rw-r--r--    1 user  primarygroup     711 Sep 20 10:44 env__prod__GetLogValues__kvmfile__0.json
-rw-r--r--    1 user  primarygroup     260 Sep 20 10:44 env__test__GeoIPFilter__kvmfile__0.json
-rw-r--r--    1 user  primarygroup     992 Sep 20 10:44 env__test__GetLogValues__kvmfile__0.json
-rw-r--r--    1 user  primarygroup     199 Sep 20 10:43 org__org-config-private__kvmfile__0.json
-rw-r--r--    1 user  primarygroup     194 Sep 20 10:43 org__org-config__kvmfile__0.json
-rw-r--r--    1 user  primarygroup    2472 Sep 20 10:44 prod__targetservers.json
-rw-r--r--    1 user  primarygroup   65125 Sep 20 10:43 products.json
drwxr-xr-x  260 user  primarygroup    8320 Sep 20 10:07 proxies
-rw-r--r--    1 user  primarygroup     127 Sep 20 10:43 proxy__kvm-demo__kvm-demo__kvmfile__0.json
-rw-r--r--    1 user  primarygroup     208 Sep 20 10:43 proxy__pingstatus-v1__pingstatus-v1-kvm1__kvmfile__0.json
drwxr-xr-x   57 user  primarygroup    1824 Sep 20 10:10 sharedflows
-rw-r--r--    1 user  primarygroup    6878 Sep 20 10:44 test__targetservers.json
```

# Import to X via apigeecli
Use apigeecli to import converted data from $X_IMPORT_DATA

**USAGE TIPS:**
- If Data Residency has been used for your organziation, use the
`--region=$REGION` option to set the prefix for the Apigee API.
See [Available Apigee API control plane hosting jurisdictions](https://cloud.google.com/apigee/docs/locations#available-apigee-api-control-plane-hosting-jurisdictions)
for more details.
- Enable debug for more details using: APIGEECLI_DEBUG=true apigeecli …

```bash
cd $X_IMPORT_DIR
export TOKEN=$(gcloud auth print-access-token)

#########################################
# Proxies
apigeecli --token=$TOKEN --org=$X_ORG apis import --folder=$X_IMPORT_DIR/proxies

#########################################
# Shared Flows
apigeecli --token=$TOKEN --org=$X_ORG sharedflows import --folder=$X_IMPORT_DIR/sharedflows

#########################################
apigeecli --token=$TOKEN --org=$X_ORG kvms import --folder=$X_IMPORT_DIR --continue-on-error

#########################################
# Target Servers
for E in ${ENVS}; do
    apigeecli --token=$TOKEN --org=$X_ORG --env=$E targetservers import --file $X_IMPORT_DIR/${E}__targetservers.json
done

#########################################
# Products, Developers, Apps
apigeecli --token=$TOKEN --org=$X_ORG products import --file=$X_IMPORT_DIR/products.json
apigeecli --token=$TOKEN --org=$X_ORG developers import --file=$X_IMPORT_DIR/developers.json
apigeecli --token=$TOKEN --org=$X_ORG apps import --file=$X_IMPORT_DIR/apps.json --dev-file=$X_IMPORT_DIR/developers.json
```

**NOTES:**

- As you run the import commands, especially for proxies and shared flows,
observe any errors that are output. This will let you know what policies and
features are not supported (StatisticsCollector policy, NodeJS base proxies, etc.)
- Many 404 errors will be shown when importing KVMs, this is due to how apigeecli works.


For example:

```bash
bundle wsdl-pass-through-calc not imported: (HTTP 400) {
  "error": {
    "code": 400,
    "message": "bundle contains errors",
    "status": "INVALID_ARGUMENT",
    "details": [
      {
        "@type": "type.googleapis.com/edge.configstore.bundle.BadBundle",
        "violations": [
          {
            "filename": "apiproxy/policies/Extract-Operation-Name.xml",
            "description": "The XMLPayload Variable type attribute \"String\" must be one of \"boolean\", \"double\", \"float\", \"integer\", \"long\", \"nodeset\", or \"string\"."
          }
        ]
      },
      {
        "@type": "type.googleapis.com/google.rpc.RequestInfo",
        "requestId": "16309497941049400312"
      }
    ]
  }
}
```

# Show what's been imported
## Use show-target-org.sh
See the complete target organization artifacts.

```bash
$APIGEE_MIGRATE_EDGE_TO_X_TOOLS_DIR/show-target-org.sh
Your active configuration is: [apigeex-custom-non-prod]
apigeex-custom-non-prod
ORG=apigeex-custom-non-prod
OK to proceed (Y/n)? Y

Proceeding...

Apps ================================
oauth-v1-app-test
pingstatus-v1-app-test
oauth-v1-app-prod
pingstatus-v1-app-prod

Developers ================================
cicd-developer-prod@google.com
cicd-developer-test@google.com

APIs ================================
oauth-v1
pingstatus-oauth-v1
pingstatus-v1
pingstatus-v1-mock

Shared Flows ================================
cors-v1
post-proxy
post-target
pre-proxy
pre-target
proxy-error-handling-v1
set-logging-values-v1

ORG KVMS ================================
org-config
org-config-private
ENV KVMS ================================
ENV KVMS: prod ================================
oauth-v1
pingstatus-v1

ENV KVMS: test ================================
oauth-v1
pingstatus-v1

PROXY KVMS ================================
PROXY KVMS: helloworld ================================
kvm-config
PROXY KVMS: kvm-demo ================================
kvm-demo
PROXY KVMS: pingstatus-v1 ================================
pingstatus-v1-kvm1

TARGETSERVERS ================================
ENV TARGETSERVERS: prod ================================
oauth-v1
pingstatus-oauth-v1
ENV TARGETSERVERS: test ================================
oauth-v1
pingstatus-oauth-v1
```

## Compare Individual Counts

### Developers
Remove `wc -l` to compare sorted emails, discrepancy could be due to case
sensitive emails not being supported.

```bash
curl -s -H "$EDGE_AUTH" https://api.enterprise.apigee.com/v1/organizations/$EDGE_ORG/developers | jq -r .[] | sort | wc -l
    77
apigeecli --token=$TOKEN --org=$X_ORG developers list | jq -r .developer[].email | sort | wc -l
    74
```

### Apps
Returns appIds, discrepancy could be due to Company Apps not being supported.

```bash
curl -s -H "$EDGE_AUTH" https://api.enterprise.apigee.com/v1/organizations/$EDGE_ORG/apps | jq -r .[] | wc -l
    107
apigeecli --token=$TOKEN --org=$X_ORG apps list | jq .app[].appId | wc -l
    106
```

### API Products
Remove `wc -l` to compare names

```bash
curl -s -H "$EDGE_AUTH" https://api.enterprise.apigee.com/v1/organizations/$EDGE_ORG/apiproducts | jq .[] | sort | wc -l
    83
apigeecli --token=$TOKEN --org=$X_ORG products list | jq .apiProduct[].name | sort | wc -l
    83
```

# Delete Resources (for testing and retries)

**WARNING WARNING WARNING**

Use with caution, these scripts deletes all resources, not just what you imported!

## Delete Developers

```bash
$APIGEE_MIGRATE_EDGE_TO_X_TOOLS_DIR/delete-developers.sh
Your active configuration is: [apigeex-custom-non-prod]
apigeex-custom-non-prod
ORG=apigeex-custom-non-prod
OK to proceed (Y/n)? Y
...
```

## Delete KVMs

```bash
$APIGEE_MIGRATE_EDGE_TO_X_TOOLS_DIR/delete-kvms.sh
Your active configuration is: [apigeex-custom-non-prod]
apigeex-custom-non-prod
ORG=apigeex-custom-non-prod
OK to proceed (Y/n)? Y
...
```
## Delete Target Org Resources (for testing and retries)

This will not delete any deployed proxies or remove target servers that are in use by a deployed proxy.

```bash
$APIGEE_MIGRATE_EDGE_TO_X_TOOLS_DIR/delete-target-org-resources.sh
Your active configuration is: [apigeex-custom-non-prod]
apigeex-custom-non-prod
ORG=apigeex-custom-non-prod
OK to proceed (Y/n)? Y
...
```



