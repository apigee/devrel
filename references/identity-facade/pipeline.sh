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

SCRIPTPATH="$( cd "$(dirname "$0")" || exit >/dev/null 2>&1 ; pwd -P )"

#################################
### function: set_idp_env_var ###
#################################
set_idp_env_var() {

    # discovery document of an OIDC compliant IdP
    idp_discovery_document_uri="$1"
    # retrieve configuration data from a discovery document
    response=$(curl --silent -k1 -fsSL -X GET -H "Accept:application/json" "$idp_discovery_document_uri")
    if [ "$( printf '%s' "$response" | grep -c error )" -ne 0  ]; then
        echo "$response"

        exit 1
    fi

    # extract data used to feed the kvm
    issuer=$( printf '%s' "$response" | jq .issuer )
    authorization_endpoint=$( printf '%s' "$response" | jq .authorization_endpoint )
    token_endpoint=$( printf '%s' "$response" | jq .token_endpoint )
    jwks_uri=$( printf '%s' "$response" | jq .jwks_uri )
    userinfo_endpoint=$( printf '%s' "$response" | jq .userinfo_endpoint )

    # set env variables for kvm (idpConfig)
    TEST_IDP_ISSUER=$(printf '%s' "$issuer" | awk -F\" '{print $2}' | awk -F\" '{print $1}')
    export TEST_IDP_ISSUER

    TEST_IDP_APIGEE_REDIRECT_URI="$2"
    export TEST_IDP_APIGEE_REDIRECT_URI

    TEST_IDP_AZ_HOSTNAME=$(printf '%s' "$authorization_endpoint" | awk -F\"https:// '{print $2}' | awk -F\" '{print $1}' | awk -F/ '{print $1}')
    export TEST_IDP_AZ_HOSTNAME

    TEST_IDP_TOKEN_HOSTNAME=$(printf '%s' "$token_endpoint" | awk -F\"https:// '{print $2}' | awk -F\" '{print $1}' | awk -F/ '{print $1}')
    export TEST_IDP_TOKEN_HOSTNAME

    TEST_IDP_JWKS_HOSTNAME=$(printf '%s' "$jwks_uri" | awk -F\"https:// '{print $2}' | awk -F\" '{print $1}' | awk -F/ '{print $1}')
    export TEST_IDP_JWKS_HOSTNAME

    TEST_IDP_USERINFO_HOSTNAME=$(printf '%s' "$userinfo_endpoint" | awk -F\"https://  '{print $2}' | awk -F\" '{print $1}' | awk -F/ '{print $1}')
    export TEST_IDP_USERINFO_HOSTNAME

    TEST_IDP_TOKEN_URI=$(printf '%s' "$token_endpoint" | awk -F "$TEST_IDP_TOKEN_HOSTNAME"'/' '{print $2}' | awk -F\" '{print $1}')
    export TEST_IDP_TOKEN_URI

    TEST_IDP_AZ_URI=$(printf '%s' "$authorization_endpoint" | awk -F "$TEST_IDP_AZ_HOSTNAME"'/' '{print $2}' | awk -F\" '{print $1}')
    export TEST_IDP_AZ_URI

    TEST_IDP_JWKS_URI=$(printf '%s' "$jwks_uri" | awk -F "$TEST_IDP_JWKS_HOSTNAME"'/' '{print $2}' | awk -F\" '{print $1}')
    export TEST_IDP_JWKS_URI

    TEST_IDP_USERINFO_URI=$(printf '%s' "$userinfo_endpoint" | awk -F "$TEST_IDP_USERINFO_HOSTNAME"'/' '{print $2}' | awk -F\" '{print $1}')
    export TEST_IDP_USERINFO_URI

    TEST_IDP_APIGEE_CLIENT_ID="${TEST_IDP_APIGEE_CLIENT_ID:=dummy-client_id-apigee123}"
    export TEST_IDP_APIGEE_CLIENT_ID

    TEST_IDP_APIGEE_CLIENT_SECRET="${TEST_IDP_APIGEE_CLIENT_SECRET:=dummy-client_secret_apigee456}"
    export TEST_IDP_APIGEE_CLIENT_SECRET
}

####################################
### function: generate_edge_json ###
####################################
generate_edge_json() {
  ENV_NAME=$1
  SCRIPTPATH="$( cd "$(dirname "$0")" || exit >/dev/null 2>&1 ; pwd -P )"

  rm -f "$SCRIPTPATH"/edge.json
  cat <<EOF >> "$SCRIPTPATH/edge.json"
{
    "version": "1.0",
    "envConfig": {
        "$ENV_NAME": {
            "targetServers": [],
            "virtualHosts": [],
            "caches": [
                {
                    "name": "IDP_JWKS_CACHE",
                    "description": "IdP JWKS Response Cache",
                    "expirySettings": {
                        "timeoutInSec": {
                            "value": "1800"
                        },
                        "valuesNull": false
                    }
                }
            ],
            "kvms": [
                {
                    "name": "idpConfigIdentityProxy",
                    "encrypted": "true",
                    "entry": [
                        {
                            "name": "idp.az.hostname",
                            "value": "$TEST_IDP_AZ_HOSTNAME"
                        },
                        {
                            "name": "idp.az.uri",
                            "value": "$TEST_IDP_AZ_URI"
                        },
                        {
                            "name": "idp.apigee.client_id",
                            "value": "$TEST_IDP_APIGEE_CLIENT_ID"
                        },
                        {
                            "name": "idp.apigee.client_secret",
                            "value": "$TEST_IDP_APIGEE_CLIENT_SECRET"
                        },
                        {
                            "name": "idp.apigee.redirect_uri",
                            "value": "$TEST_IDP_APIGEE_REDIRECT_URI"
                        },
                        {
                            "name": "idp.token.hostname",
                            "value": "$TEST_IDP_TOKEN_HOSTNAME"
                        },
                        {
                            "name": "idp.token.uri",
                            "value": "$TEST_IDP_TOKEN_URI"
                        },
                        {
                            "name": "idp.jwks.hostname",
                            "value": "$TEST_IDP_JWKS_HOSTNAME"
                        },
                        {
                            "name": "idp.jwks.uri",
                            "value": "$TEST_IDP_JWKS_URI"
                        },
                        {
                            "name": "idp.userinfo.hostname",
                            "value": "$TEST_IDP_USERINFO_HOSTNAME"
                        },
                        {
                            "name": "idp.userinfo.uri",
                            "value": "$TEST_IDP_USERINFO_URI"
                        },
                        {
                            "name": "idp.issuer",
                            "value": "$TEST_IDP_ISSUER"
                        }
                    ]
                }
            ]
        }
    },
    "orgConfig": {
        "apiProducts": [
            {
                "name": "IdentityFacade",
                "apiResources": [],
                "approvalType": "auto",
                "attributes": [
                    {
                        "name": "access",
                        "value": "public"
                    }
                ],
                "description": "",
                "displayName": "Identity Facade",
                "environments": [
                    "$ENV_NAME"
                ],
                "proxies": [
                    "identity-facade-v1"
                ]
            }
        ],
        "developers": [
            {
                "email": "janedoe@example.com",
                "firstName": "Jane",
                "lastName": "Doe",
                "userName": "janedoe",
                "attributes": []
            }
        ],
        "developerApps": {
            "janedoe@example.com": [
                {
                    "name": "identityApp",
                    "attributes": [
                        {
                            "name": "displayName",
                            "value": "identity App"
                        }
                    ],
                    "apiProducts": [
                        "IdentityFacade"
                    ],
                    "callbackUrl": "https://httpbin.org/get",
                    "scopes": []
                }
            ]
        }
    }
}
EOF
}

####################################################
### function: generate_post_data_app_credentials ###
####################################################
generate_post_data_app_credentials() {
cat <<EOF
{
  "consumerKey": "$TEST_APP_CONSUMER_KEY",
  "consumerSecret": "xsecret"
}
EOF
}

################################
### function: set_idp_env_var ###
#################################
set_functional_test_env_var() {

    # use timestamp (parameter) to create a unique value
    TEST_APP_CONSUMER_KEY="xkey-$1"
    export TEST_APP_CONSUMER_KEY
    TEST_APP_CONSUMER_SECRET='xsecret'
    export TEST_APP_CONSUMER_SECRET
}


# generate a timestamp to make some values unique
timestamp=$(date '+%s')
export PATH="$PATH:$SCRIPTPATH/../../tools/apigee-sackmesser/bin"

if [ -z "$1" ] || [ "$1" = "--apigeeapi" ];then
    echo "[INFO] Deploying Identitiy facade to Apigee API (For Edge)"

    # deploy the OIDC mock identity provider...
    if [ -z ${IDP_DISCOVERY_DOCUMENT+x} ];then
        sackmesser deploy --apigeeapi -o "$APIGEE_ORG" -e "$APIGEE_ENV" -u "$APIGEE_USER" -p "$APIGEE_PASS" -d "$SCRIPTPATH"/../oidc-mock
        (cd "$SCRIPTPATH"/../oidc-mock && npm i && TEST_HOST="$APIGEE_ORG-$APIGEE_ENV.apigee.net" npm test)
    fi

    # set env variables for google oidc
    DISCOVERY_DOCUMENT_URI="${IDP_DISCOVERY_DOCUMENT:-https://$APIGEE_ORG-$APIGEE_ENV.apigee.net/v1/openid-connect/.well-known/openid-configuration}"
    CALLBACK_URL="https://$APIGEE_ORG-$APIGEE_ENV.apigee.net/v1/oauth20/callback"
    set_idp_env_var "$DISCOVERY_DOCUMENT_URI" "$CALLBACK_URL"

    # generate edge.json file
    generate_edge_json "$APIGEE_ENV"

    set_functional_test_env_var "$timestamp"

    # deploy Apigee artifacts: proxy, developer, app, product cache, kvm and proxy
    sackmesser deploy --apigeeapi -o "$APIGEE_ORG" -e "$APIGEE_ENV" -u "$APIGEE_USER" -p "$APIGEE_PASS" -d "$SCRIPTPATH"

    # set developer app (apigee_client) credentials
    curl --fail --silent -X POST \
        -u "$APIGEE_USER":"$APIGEE_PASS" -H "Content-Type:application/json" \
        --data "{ \"consumerKey\": \"$TEST_APP_CONSUMER_KEY\", \"consumerSecret\": \"$TEST_APP_CONSUMER_SECRET\" }" \
        https://api.enterprise.apigee.com/v1/organizations/"$APIGEE_ORG"/developers/janedoe@example.com/apps/identityApp/keys/create

    # Set identity product for 'identityApp'
    curl --fail --silent -X POST \
        -u "$APIGEE_USER":"$APIGEE_PASS" -H "Content-Type:application/json" \
        --data "{ \"apiProducts\": [\"IdentityFacade\"] }" \
        https://api.enterprise.apigee.com/v1/organizations/"$APIGEE_ORG"/developers/janedoe@example.com/apps/identityApp/keys/"$TEST_APP_CONSUMER_KEY"

    # execute integration tests only against mock IDP
    if [ -z ${IDP_DISCOVERY_DOCUMENT+x} ]; then
        (cd "$SCRIPTPATH" && npm i && TEST_HOST="$APIGEE_ORG-$APIGEE_ENV.apigee.net" npm run test)
    else
        echo "no tests run for custom OIDC Idp: $DP_DISCOVERY_DOCUMENT"
    fi
fi

if [ -z "$1" ] || [ "$1" = "--googleapi" ];then
    echo "[INFO] Deploying Identitiy facade to Google API (For X/hybrid)"
    APIGEE_TOKEN=$(gcloud auth print-access-token);

    if [ -z ${IDP_DISCOVERY_DOCUMENT+x} ];
    then
        sackmesser deploy --googleapi -o "$APIGEE_X_ORG" -e "$APIGEE_X_ENV" -t "$APIGEE_TOKEN" -d "$SCRIPTPATH"/../oidc-mock
        (cd "$SCRIPTPATH"/../oidc-mock && npm i && TEST_HOST="$APIGEE_X_HOSTNAME" npm test)
    fi

     # set env variables for google oidc
    DISCOVERY_DOCUMENT_URI="${IDP_DISCOVERY_DOCUMENT:-https://$APIGEE_X_HOSTNAME/v1/openid-connect/.well-known/openid-configuration}"
    CALLBACK_URL="https://$APIGEE_X_HOSTNAME/v1/oauth20/callback"
    set_idp_env_var "$DISCOVERY_DOCUMENT_URI" "$CALLBACK_URL"

    # generate edge.json file
    generate_edge_json "$APIGEE_X_ENV"

    set_functional_test_env_var "$timestamp"

    # # deploy Apigee artifacts: proxy, developer, app, product cache, kvm and proxy
    sackmesser deploy --googleapi -o "$APIGEE_X_ORG" -e "$APIGEE_X_ENV" -t "$APIGEE_TOKEN" -h "$APIGEE_X_HOSTNAME" -d "$SCRIPTPATH"

    # set developer app (apigee_client) credentials
    curl --fail --silent -X POST \
        -H "Authorization: Bearer $APIGEE_TOKEN" -H "Content-Type:application/json" \
        --data "{ \"consumerKey\": \"$TEST_APP_CONSUMER_KEY\", \"consumerSecret\": \"$TEST_APP_CONSUMER_SECRET\" }" \
        https://apigee.googleapis.com/v1/organizations/"$APIGEE_X_ORG"/developers/janedoe@example.com/apps/identityApp/keys/create

    # Set identity product for 'identityApp'
    curl --fail --silent -X POST \
        -H "Authorization: Bearer $APIGEE_TOKEN" -H "Content-Type:application/json" \
        --data "{ \"apiProducts\": [\"IdentityFacade\"] }" \
        https://apigee.googleapis.com/v1/organizations/"$APIGEE_X_ORG"/developers/janedoe@example.com/apps/identityApp/keys/"$TEST_APP_CONSUMER_KEY"

    # execute integration tests only against mock IDP
    if [ -z ${IDP_DISCOVERY_DOCUMENT+x} ]; then
        (cd "$SCRIPTPATH" && npm i && TEST_HOST="$APIGEE_X_HOSTNAME" npm run test)
    else
        echo "no tests run for custom OIDC Idp: $DP_DISCOVERY_DOCUMENT"
    fi
fi
