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

#################################
### function: set_idp_env_var ###
#################################
set_idp_env_var() {

    # retrieve configuration data from a discovery document
    response=$(curl --silent -k1 -fsSL -X GET -H "Accept:application/json" https://"$APIGEE_ORG"-"$APIGEE_ENV".apigee.net/v1/openid-connect/.well-known/openid-configuration)
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
    
    TEST_IDP_APIGEE_REDIRECT_URI="https://$APIGEE_ORG-$APIGEE_ENV.apigee.net/v1/oauth20/callback"
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

    TEST_IDP_APIGEE_CLIENT_ID="dummy-client_id-123"
    export TEST_IDP_APIGEE_CLIENT_ID

    TEST_IDP_APIGEE_CLIENT_SECRET="dummy-client_secret-456"
    export TEST_IDP_APIGEE_CLIENT_SECRET
}

#################################
### function: set_idp_env_var ###
#################################
set_functest_env_var() {

    #APP_CLIENT_ID
    APP_CLIENT_ID="xkey"
    export APP_CLIENT_ID

    #APP_CLIENT_SECRET
    APP_CLIENT_SECRET="xsecret"
    export APP_CLIENT_SECRET
}

####################################################
### function: generate_post_data_app_credentials ###
####################################################
generate_post_data_app_credentials()
{
  cat <<EOF
{
  "consumerKey": "xkey",
  "consumerSecret": "xsecret"
}
EOF
}

#########################################################
### function: generate_post_data_app_identity_product ###
#########################################################
generate_post_data_app_identity_product()
{
  cat <<EOF
{ 
    "apiProducts": ["IdentityProduct"] 
}
EOF
}

########################################
### function: set_devapp_credentials ###
########################################
set_devapp_credentials() {
    # retrieve configuration data from a keycloak endpoint
    response=$(curl --silent -X POST --data "$(generate_post_data_app_credentials)" -u "$APIGEE_USER":"$APIGEE_PASS" -H "Content-Type:application/json" https://api.enterprise.apigee.com/v1/organizations/"$APIGEE_ORG"/developers/helene.dozi.demo@gmail.com/apps/identityApp/keys/create)
    if [ "$( printf '%s' "$response" | grep -c error )" -ne 0  ]; then
        echo "$response"
        
        exit 1
    fi
}

####################################
### function: set_devapp_product ###
####################################
set_devapp_product() {
    # retrieve configuration data from a keycloak endpoint
    response=$(curl --silent -X POST --data "$(generate_post_data_app_identity_product)" -u "$APIGEE_USER":"$APIGEE_PASS" -H "Content-Type:application/json" https://api.enterprise.apigee.com/v1/organizations/"$APIGEE_ORG"/developers/helene.dozi.demo@gmail.com/apps/identityApp/keys/xkey)
    if [ "$( printf '%s' "$response" | grep -c error )" -ne 0  ]; then
        echo "$response"

        exit 1
    fi
}


# set env variables for google oidc
set_idp_env_var

# set env variables for testing : to be removed when env variables can be set differently
set_functest_env_var

# deploy Apigee artifacts: proxy, developer, app, product cache, kvm and proxy
mvn install -P"$APIGEE_ENV" -Dapigee.config.options=update

# set developer app (apigee_client) credentials with the exact same values than the one in the keycloak IdP
set_devapp_credentials

# set developer app (apigeee_client) product
set_devapp_product

# execute integration tests
npm i
npm run test
