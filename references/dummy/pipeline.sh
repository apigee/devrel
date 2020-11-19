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


set -x 
set -e

cd ./identity-api-v1

# discovery docs: google, keycloak
google_discovery_doc="https://accounts.google.com/.well-known/openid-configuration"
keycloak_discovery_doc="https://keycloak.iloveapis.io/auth/realms/demo/.well-known/openid-configuration"

#################################
### function: set_idp_env_var ###
#################################
set_idp_env_var() {

    # retrieve configuration data from the google discovery document
    response=$(curl --silent -k1 -X GET -H "Accept:application/json" $keycloak_discovery_doc)
    if [ $( grep -c error <<< "$response" ) -ne 0  ]; then
        echo "$response"
        
        exit 1
    fi

    # extract data used to feed the kvm
    issuer=$( jq .issuer <<< "$response" )
    authorization_endpoint=$( jq .authorization_endpoint <<< "$response" )
    token_endpoint=$( jq .token_endpoint <<< "$response" )
    jwks_uri=$( jq .jwks_uri <<< "$response" )
    userinfo_endpoint=$( jq .userinfo_endpoint <<< "$response" )


    # set env variables for kvm (idpConfig)
    export TEST_IDP_ISSUER=`awk -F\" '{print $2}' <<< $issuer | awk -F\" '{print $1}'`
    export TEST_IDP_APIGEE_REDIRECT_URI="https://$APIGEE_ORG-$APIGEE_ENV.apigee.net/v1/oauth20/callback"
    export TEST_IDP_AZ_HOSTNAME=`awk -F\"https://  '{print $2}' <<< $authorization_endpoint | awk -F\" '{print $1}' | awk -F/ '{print $1}'`
    export TEST_IDP_TOKEN_HOSTNAME=`awk -F\"https://  '{print $2}' <<< $token_endpoint | awk -F\" '{print $1}' | awk -F/ '{print $1}'`
    export TEST_IDP_JWKS_HOSTNAME=`awk -F\"https://  '{print $2}' <<< $jwks_uri | awk -F\" '{print $1}' | awk -F/ '{print $1}'`
    export TEST_IDP_USERINFO_HOSTNAME=`awk -F\"https://  '{print $2}' <<< $userinfo_endpoint | awk -F\" '{print $1}' | awk -F/ '{print $1}'`
    export TEST_IDP_TOKEN_URI=`awk -F $TEST_IDP_TOKEN_HOSTNAME'/' '{print $2}' <<< $token_endpoint | awk -F\" '{print $1}'`
    export TEST_IDP_AZ_URI=`awk -F $TEST_IDP_AZ_HOSTNAME'/' '{print $2}' <<< $authorization_endpoint | awk -F\" '{print $1}'`
    export TEST_IDP_JWKS_URI=`awk -F $TEST_IDP_JWKS_HOSTNAME'/' '{print $2}' <<< $jwks_uri | awk -F\" '{print $1}'`
    export TEST_IDP_USERINFO_URI=`awk -F $TEST_IDP_USERINFO_HOSTNAME'/' '{print $2}' <<< $userinfo_endpoint | awk -F\" '{print $1}'` 
    export TEST_IDP_APIGEE_CLIENT_ID=$IDP_APIGEE_CLIENT_ID
    export TEST_IDP_APIGEE_CLIENT_SECRET=$IDP_APIGEE_CLIENT_SECRET
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
    response=$(curl --silent -X POST --data "$(generate_post_data_app_credentials)" -u $APIGEE_USER:$APIGEE_PASS -H "Content-Type:application/json" https://api.enterprise.apigee.com/v1/organizations/$APIGEE_ORG/developers/helene.dozi.demo@gmail.com/apps/identityApp/keys/create)
    if [ $( grep -c error <<< "$response" ) -ne 0  ]; then
        echo "$response"
        
        exit 1
    fi
}

####################################
### function: set_devapp_product ###
####################################
set_devapp_product() {
    # retrieve configuration data from a keycloak endpoint
    response=$(curl --silent -X POST --data "$(generate_post_data_app_identity_product)" -u $APIGEE_USER:$APIGEE_PASS -H "Content-Type:application/json" https://api.enterprise.apigee.com/v1/organizations/$APIGEE_ORG/developers/helene.dozi.demo@gmail.com/apps/identityApp/keys/xkey)
    if [ $( grep -c error <<< "$response" ) -ne 0  ]; then
        echo "$response"
        
        exit 1
    fi
}


# set env variables for google oidc
set_idp_env_var

# deploy Apigee artifacts: developer, app, product cache, kvm and proxy
mvn install -P$APIGEE_ENV -Dapigee.config.options=update 

# set developer app (apigee_client) credentials with the exact same values than the one in the keycloak IdP
set_devapp_credentials

# set developer app (apigeee_client) product
set_devapp_product

# execute integration tests
#npm i
#npm test

