#!/bin/sh
# Copyright 2020 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e

#
# this script cater for CI/CD and integrated testing based on vault mock server
# 
# adjusted artifacts are put into a ./generated directory


SCRIPTPATH="$( cd "$(dirname "$0")" || exit >/dev/null 2>&1 ; pwd -P )"
export PATH="$PATH:$SCRIPTPATH/../../tools/apigee-sackmesser/bin"


#
# Java Callout
#

"$SCRIPTPATH"/apigee-lib-install.sh "$SCRIPTPATH"/generated/apigee-lib

(cd "$SCRIPTPATH"/vault-facade-callout && mvn package)

#
# Vault Proxy
#

TOKEN="$(gcloud config config-helper --force-auth-refresh --format json | jq -r '.credential.access_token')"

mkdir -p "$SCRIPTPATH/generated"

## vault mock
export MOCK_PROXY=vault-mock-proxy

export VAULT_CONFIG=generated/vault-facade-config
mkdir -p $VAULT_CONFIG


## GENERATED: configure and deploy Vault Facade API Proxy
export VAULT_PROXY=generated/vault-facade-proxy
mkdir -p "$SCRIPTPATH"/ -p $VAULT_PROXY

cp -R "$SCRIPTPATH"/vault-facade-proxy/* $VAULT_PROXY

mkdir -p $VAULT_PROXY/apiproxy/resources/java
cp vault-facade-callout/target/vault-keys-to-jwks-0.0.1.jar $VAULT_PROXY/apiproxy/resources/java

if [ -z "$SKIP_MOCKING" ]; then
    ## GENERATED: generate config objects [targetserver and kvm]
    export VAULT_HOSTNAME="$APIGEE_X_HOSTNAME"
    export VAULT_PORT=443
    export VAULT_SSL_INFO='"sSLInfo": {
                    "enabled": true,
                    "ignoreValidationErrors": false
                    },'

    export VAULT_TOKEN=dummy-token


    # adjust for mocking
    export TARGET_SERVER_DEF="$SCRIPTPATH/$VAULT_PROXY/apiproxy/targets/default.xml"
    # shellcheck disable=2005
    echo "$(awk  '/<Path>/{gsub(/<Path>/,"<Path>/vault-mock");print;next} //' "$TARGET_SERVER_DEF" )" > "$TARGET_SERVER_DEF"

    sackmesser deploy --googleapi -o "$APIGEE_X_ORG" -e "$APIGEE_X_ENV" -t "$TOKEN" -d "$SCRIPTPATH/$MOCK_PROXY"
fi

envsubst < "$SCRIPTPATH/vault-facade-config/edge.json.tpl" > "$SCRIPTPATH/$VAULT_CONFIG/edge.json"

sackmesser deploy --googleapi -o "$APIGEE_X_ORG" -e "$APIGEE_X_ENV" -t "$TOKEN" -d "$SCRIPTPATH/$VAULT_CONFIG"

sackmesser deploy --googleapi -o "$APIGEE_X_ORG" -e "$APIGEE_X_ENV" -t "$TOKEN" -d "$SCRIPTPATH/$VAULT_PROXY"

## integration tests
(cd "$SCRIPTPATH" && npm install --no-fund && TEST_HOSTNAME="$APIGEE_X_HOSTNAME" npm run test)
