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

  rm -f "$SCRIPTPATH"/identity-facade-v1/edge.json
  cat <<EOF >> "$SCRIPTPATH/identity-facade-v1/edge.json"
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

#################################
### function: set_idp_env_var ###
#################################
set_functional_test_env_var() {

    # use timestamp (parameter) to create a unique value
    TEST_APP_CONSUMER_KEY="xkey-$1"
    export TEST_APP_CONSUMER_KEY
    TEST_APP_CONSUMER_SECRET='xsecret'
    export TEST_APP_CONSUMER_SECRET
    # pkce test variables. Challenge method is set to 'S256' (sha256)
    TEST_APP_PKCE_CODE_CHALLENGE='hoLP4vNbBccHkhNAbk_jbyLhlGwgeoRyo53A-Luiirg'
    export TEST_APP_PKCE_CODE_CHALLENGE
    TEST_APP_PKCE_CODE_VERIFIER='iloveapis1234567890'
    export TEST_APP_PKCE_CODE_VERIFIER
}

#################################
### function: set_pkce_config ###
#################################
set_pkce_config() {

    # pkce comment patterns used in files
    EMPTY_STRING=''
    APICKLI_FPARAM_PKCE_CODE_VERIFIER_PATTERN='@PKCECodeVerifier@'

    if [ "$1" = "true" ];then

        echo "[INFO] PKCE enabled - creating PKCE configuration for identity facade"

        # pkce comment patterns used in files
        START_PKCE_COMMENT_PATTERN='<!-- @PKCE'
        END_PKCE_COMMENT_PATTERN='@PKCE -->'
        APICKLI_FPARAM_PKCE_CODE_VERIFIER="\| code_verifier \| \`codeVerifier\` \|"

        # replace pkce comment patterns in proxy configuration
        sed -i.bak "s|$START_PKCE_COMMENT_PATTERN|$EMPTY_STRING|" "$SCRIPTPATH"/identity-facade-v1/apiproxy/policies/AM-StateAttributes.xml
        sed -i.bak "s|$END_PKCE_COMMENT_PATTERN|$EMPTY_STRING|" "$SCRIPTPATH"/identity-facade-v1/apiproxy/policies/AM-StateAttributes.xml
        sed -i.bak "s|$START_PKCE_COMMENT_PATTERN|$EMPTY_STRING|" "$SCRIPTPATH"/identity-facade-v1/apiproxy/policies/EV-InputQueryParams.xml
        sed -i.bak "s|$END_PKCE_COMMENT_PATTERN|$EMPTY_STRING|" "$SCRIPTPATH"/identity-facade-v1/apiproxy/policies/EV-InputQueryParams.xml
        sed -i.bak "s|$START_PKCE_COMMENT_PATTERN|$EMPTY_STRING|" "$SCRIPTPATH"/identity-facade-v1/apiproxy/policies/OA2-GenerateAzCode-State2.xml
        sed -i.bak "s|$END_PKCE_COMMENT_PATTERN|$EMPTY_STRING|" "$SCRIPTPATH"/identity-facade-v1/apiproxy/policies/OA2-GenerateAzCode-State2.xml
        sed -i.bak "s|$START_PKCE_COMMENT_PATTERN|$EMPTY_STRING|" "$SCRIPTPATH"/identity-facade-v1/apiproxy/policies/OA2-StoreExternalAuthorizationCode.xml
        sed -i.bak "s|$END_PKCE_COMMENT_PATTERN|$EMPTY_STRING|" "$SCRIPTPATH"/identity-facade-v1/apiproxy/policies/OA2-StoreExternalAuthorizationCode.xml
        sed -i.bak "s|$START_PKCE_COMMENT_PATTERN|$EMPTY_STRING|" "$SCRIPTPATH"/identity-facade-v1/apiproxy/proxies/default.xml
        sed -i.bak "s|$END_PKCE_COMMENT_PATTERN|$EMPTY_STRING|" "$SCRIPTPATH"/identity-facade-v1/apiproxy/proxies/default.xml
        # replace pkce patterns in apickli tests
        sed -i.bak "s|$APICKLI_FPARAM_PKCE_CODE_VERIFIER_PATTERN|$APICKLI_FPARAM_PKCE_CODE_VERIFIER|" "$SCRIPTPATH"/identity-facade-v1/test/integration/features/identity-facade.end2end.feature
        sed -i.bak "s|$APICKLI_FPARAM_PKCE_CODE_VERIFIER_PATTERN|$APICKLI_FPARAM_PKCE_CODE_VERIFIER|" "$SCRIPTPATH"/identity-facade-v1/test/integration/features/identity-facade.token.feature

        # remove .bak files
        rm "$SCRIPTPATH"/identity-facade-v1/apiproxy/policies/AM-StateAttributes.xml.bak
        rm "$SCRIPTPATH"/identity-facade-v1/apiproxy/policies/EV-InputQueryParams.xml.bak
        rm "$SCRIPTPATH"/identity-facade-v1/apiproxy/policies/OA2-GenerateAzCode-State2.xml.bak
        rm "$SCRIPTPATH"/identity-facade-v1/apiproxy/policies/OA2-StoreExternalAuthorizationCode.xml.bak
        rm "$SCRIPTPATH"/identity-facade-v1/apiproxy/proxies/default.xml.bak
        rm "$SCRIPTPATH"/identity-facade-v1/test/integration/features/identity-facade.end2end.feature.bak
        rm "$SCRIPTPATH"/identity-facade-v1/test/integration/features/identity-facade.token.feature.bak
    else
        echo "[INFO] PKCE disabled - keep identity facade configuration unchanged"

         # replace pkce patterns in apickli tests
        sed -i.bak "s|$APICKLI_FPARAM_PKCE_CODE_VERIFIER_PATTERN|$EMPTY_STRING|" "$SCRIPTPATH"/identity-facade-v1/test/integration/features/identity-facade.end2end.feature
        sed -i.bak "s|$APICKLI_FPARAM_PKCE_CODE_VERIFIER_PATTERN|$EMPTY_STRING|" "$SCRIPTPATH"/identity-facade-v1/test/integration/features/identity-facade.token.feature

        # remove pkce tests feature files
        rm "$SCRIPTPATH"/identity-facade-v1/test/integration/features/identity-facade.authorize-pkce.feature
        rm "$SCRIPTPATH"/identity-facade-v1/test/integration/features/identity-facade.token-pkce.feature

        # remove .bak files
        rm "$SCRIPTPATH"/identity-facade-v1/test/integration/features/identity-facade.end2end.feature.bak
        rm "$SCRIPTPATH"/identity-facade-v1/test/integration/features/identity-facade.token.feature.bak
    fi
}

####################################
### function: generate_authz_url ###
####################################
generate_authz_url() {
    HOST=$1
    BASE_PATH="/v1/oauth20"
    AZ_URI="/authorize"
    CLIENT_ID="?client_id="$2
    RESPONSE_TYPE="&response_type=code"
    SCOPE="&scope=openid email profile"
    STATE="&state=abcd-1234"
    REDIRECT_URI="&redirect_uri=https://httpbin.org/get"

    # is pkce enabled (=true) or not
    if [ "$4" = "true" ];then
        CODE_CHALLENGE_METHOD="&code_challenge_method=S256"
        CODE_CHALLENGE="&code_challenge="$3
    else
        CODE_CHALLENGE_METHOD=""
        CODE_CHALLENGE=""
    fi
    
    printf "\n"
    printf "##########################\n"
    printf "#### Authorization URL ###\n"
    printf "##########################\n"
    printf "You can copy/paste the following authorization URL into your Web browser to initiate the OIDC flow:\n"
    printf "https://"%s%s%s%s%s%s%s%s%s%s \
                    "$HOST" \
                    "$BASE_PATH" \
                    "$AZ_URI" \
                    "$CLIENT_ID" \
                    "$RESPONSE_TYPE" \
                    "$SCOPE" \
                    "$STATE" \
                    "$REDIRECT_URI" \
                    "$CODE_CHALLENGE_METHOD" \
                    "$CODE_CHALLENGE"
    printf "\n\n"
}

# generate a timestamp to make some values unique
timestamp=$(date '+%s')
export PATH="$PATH:$SCRIPTPATH/../../tools/apigee-sackmesser/bin"

# default value for pkce enablement
DEFAULT_IS_PKCE_ENABLED=false

# is okce enabled (=true) or not (=false)
IS_PKCE_ENABLED="${IS_PKCE_ENABLED:-"$DEFAULT_IS_PKCE_ENABLED"}"

 # clean up
rm -rf "$SCRIPTPATH"/identity-facade-v1

# Copy identity facade template and replace variables in configuration files
cp -r ./template-identity-facade-v1 ./identity-facade-v1

# set pkce config if pkce is enabled
set_pkce_config "$IS_PKCE_ENABLED"

if [ -z "$1" ] || [ "$1" = "--apigeeapi" ];then
    echo "[INFO] Deploying Identitiy facade to Apigee API (For Edge)"

    # deploy the OIDC mock identity provider...
    if [ -z ${IDP_DISCOVERY_DOCUMENT+x} ];then
        sackmesser deploy --apigeeapi -o "$APIGEE_ORG" -e "$APIGEE_ENV" -u "$APIGEE_USER" -p "$APIGEE_PASS" -d "$SCRIPTPATH"/../oidc-mock
        (cd "$SCRIPTPATH"/../oidc-mock && npm i --no-fund && TEST_HOST="$APIGEE_ORG-$APIGEE_ENV.apigee.net" npm test)
    fi

    # set env variables for google oidc
    DISCOVERY_DOCUMENT_URI="${IDP_DISCOVERY_DOCUMENT:-https://$APIGEE_ORG-$APIGEE_ENV.apigee.net/v1/openid-connect/.well-known/openid-configuration}"
    CALLBACK_URL="https://$APIGEE_ORG-$APIGEE_ENV.apigee.net/v1/oauth20/callback"
    set_idp_env_var "$DISCOVERY_DOCUMENT_URI" "$CALLBACK_URL"

    # generate edge.json file
    generate_edge_json "$APIGEE_ENV"

    set_functional_test_env_var "$timestamp"

    # deploy Apigee artifacts: proxy, developer, app, product cache, kvm and proxy
    sackmesser deploy --apigeeapi -o "$APIGEE_ORG" -e "$APIGEE_ENV" -u "$APIGEE_USER" -p "$APIGEE_PASS" -d "$SCRIPTPATH"/identity-facade-v1

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
        (cd "$SCRIPTPATH"/identity-facade-v1 && npm i --no-fund && TEST_HOST="$APIGEE_ORG-$APIGEE_ENV.apigee.net" IS_PKCE_ENABLED="$IS_PKCE_ENABLED" npm run test)
    else
        echo "no tests run for custom OIDC Idp: $IDP_DISCOVERY_DOCUMENT"
    fi

    # generate authorization URL
    generate_authz_url "$APIGEE_ORG-$APIGEE_ENV.apigee.net" "$TEST_APP_CONSUMER_KEY" "$TEST_APP_PKCE_CODE_CHALLENGE" "$IS_PKCE_ENABLED"
fi

if [ -z "$1" ] || [ "$1" = "--googleapi" ];then
    echo "[INFO] Deploying Identitiy facade to Google API (For X/hybrid)"
    APIGEE_TOKEN=$(gcloud auth print-access-token);

    if [ -z ${IDP_DISCOVERY_DOCUMENT+x} ];
    then
        sackmesser deploy --googleapi -o "$APIGEE_X_ORG" -e "$APIGEE_X_ENV" -t "$APIGEE_TOKEN" -d "$SCRIPTPATH"/../oidc-mock
        (cd "$SCRIPTPATH"/../oidc-mock && npm i --no-fund && TEST_HOST="$APIGEE_X_HOSTNAME" npm test)
    fi

     # set env variables for google oidc
    DISCOVERY_DOCUMENT_URI="${IDP_DISCOVERY_DOCUMENT:-https://$APIGEE_X_HOSTNAME/v1/openid-connect/.well-known/openid-configuration}"
    CALLBACK_URL="https://$APIGEE_X_HOSTNAME/v1/oauth20/callback"
    set_idp_env_var "$DISCOVERY_DOCUMENT_URI" "$CALLBACK_URL"

    # generate edge.json file
    generate_edge_json "$APIGEE_X_ENV"

    set_functional_test_env_var "$timestamp"

    # # deploy Apigee artifacts: proxy, developer, app, product cache, kvm and proxy
    sackmesser deploy --googleapi -o "$APIGEE_X_ORG" -e "$APIGEE_X_ENV" -t "$APIGEE_TOKEN" -h "$APIGEE_X_HOSTNAME" -d "$SCRIPTPATH"/identity-facade-v1

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
        (cd "$SCRIPTPATH"/identity-facade-v1 && npm i --no-fund && TEST_HOST="$APIGEE_X_HOSTNAME" IS_PKCE_ENABLED="$IS_PKCE_ENABLED" npm run test)
    else
        echo "no tests run for custom OIDC Idp: $IDP_DISCOVERY_DOCUMENT"
    fi

    # generate authorization URL
    generate_authz_url "$APIGEE_X_HOSTNAME" "$TEST_APP_CONSUMER_KEY" "$TEST_APP_PKCE_CODE_CHALLENGE" "$IS_PKCE_ENABLED"
fi
