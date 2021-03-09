# Apigee Portable Proxy Deployment Utility

The Apigee portable deployment utility lets you deploy API proxies to Apigee
Edge as well as hybrid/X without configuring any additional resources and
provides a docker container that contains all necessary dependencies.

```sh
$ deploy -h

usage: deploy.sh -e ENV -o ORG [-t TOKEN | -u USER -p PASSWORD] [options]

Apigee portable deployment utility.

Options:
-b,--base-path, overrides the default base path for the API proxy
-d,--directory, path to the apiproxy folder to be deployed
-e,--environment, Apigee environment name
-g,--github, Link to proxy bundle on github
-n,--api, Overrides the default API proxy name
-o,--organization, Apigee organization name
-u,--username, Apigee User Name (Edge only)
-p,--password, Apigee User Password (Edge only)
-m,--mfa, Apigee MFA code (Edge only)
-t,--token, GCP Token (X,hybrid only)
--description, Human friendly proxy description
```

## Example usages as a script

### Secenario: Deploy a proxy on Github to Apigee X / hybrid

```sh
./deploy.sh -g https://github.com/apigee/devrel/tree/main/references/cicd-pipeline/apiproxy \
-t $TOKEN \
-o $APIGEE_ORG \
-e $APIGEE_ENV \
-b "/airports/v1"
```

### Scenario: Deploy a local proxy to Apigee Edge

```sh
MFA=<MFA token goes here>

./deploy.sh -d $PWD/../../references/cicd-pipeline/apiproxy \
--description "deployment from local folder" \
-n test-cicd-v0 \
-b "/airports/test-v1" \
-u $APIGEE_USER \
-p $APIGEE_PASS \
-m $MFA \
-o $APIGEE_ORG \
-e $APIGEE_ENV
```

## Example usages as a Docker Container

### Build the docker image

```sh
docker build -t apigeedeploy .
```

### Secenario: Deploy a proxy on Github to Apigee X / hybrid

```sh
docker run apigeedeploy \
-g https://github.com/apigee/devrel/tree/main/references/cicd-pipeline/apiproxy \
-t $TOKEN \
-o $APIGEE_ORG \
-e $APIGEE_ENV \
-b "/airports/v1"
```

### Scenario: Deploy a local proxy to Apigee Edge

```sh
docker run \
-v $PWD/../../references/cicd-pipeline/apiproxy:/opt/apigee/apiproxy \
apigeedeploy \
-n test-cicd-v0 \
-b "/airports/test-v1" \
-u $APIGEE_USER \
-p $APIGEE_PASS \
-o $APIGEE_ORG \
-e $APIGEE_ENV
```
