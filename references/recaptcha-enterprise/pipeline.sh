#!/bin/sh
# Copyright 2022 Google LLC
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

#########################################
### function: generate_edge_mock_json ###
#########################################
generate_edge_mock_json() {
  ENV_NAME=$1
  SCRIPTPATH="$( cd "$(dirname "$0")" || exit >/dev/null 2>&1 ; pwd -P )"

  rm -f "$SCRIPTPATH"/data-proxy-v1/edge.json
  cat <<EOF >> "$SCRIPTPATH/data-proxy-v1/edge.json"
{
    "version": "1.0",
    "envConfig": {},
    "orgConfig": {
        "apiProducts": [
            {
                "name": "RecaptchaEnterprise",
                "apiResources": [],
                "approvalType": "auto",
                "attributes": [
                    {
                        "name": "access",
                        "value": "public"
                    }
                ],
                "description": "",
                "displayName": "Recaptcha Enterprise Product",
                "environments": [
                    "$ENV_NAME"
                ],
                "proxies": [
                    "data-proxy-v1"
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
                    "name": "app-recaptcha-enterprise",
                    "attributes": [
                        {
                            "name": "GCP_PROJECT_ID",
                            "value": "mock-gcp-project-id"
                        },
                        {
                            "name": "SITE_KEY",
                            "value": "mock-recaptcha-enterprise-sitekey"
                        }
                    ],
                    "apiProducts": [
                        "RecaptchaEnterprise"
                    ],
                    "callbackUrl": "",
                    "scopes": []
                }
            ]
        }
    }
}
EOF
}

####################################
### function: generate_edge_json ###
####################################
generate_edge_json() {
  ENV_NAME=$1
  GCP_PROJECT_ID=$2
  SITEKEY_ALWAYS_1=$3
  SITEKEY_ALWAYS_0=$4
  SCRIPTPATH="$( cd "$(dirname "$0")" || exit >/dev/null 2>&1 ; pwd -P )"

  rm -f "$SCRIPTPATH"/data-proxy-v1/edge.json
  cat <<EOF >> "$SCRIPTPATH/data-proxy-v1/edge.json"
{
    "version": "1.0",
    "envConfig": {},
    "orgConfig": {
        "apiProducts": [
            {
                "name": "RecaptchaEnterprise",
                "apiResources": [],
                "approvalType": "auto",
                "attributes": [
                    {
                        "name": "access",
                        "value": "public"
                    }
                ],
                "description": "",
                "displayName": "Recaptcha Enterprise Product",
                "environments": [
                    "$ENV_NAME"
                ],
                "proxies": [
                    "data-proxy-v1"
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
                    "name": "app-recaptcha-enterprise-always1",
                    "attributes": [
                        {
                            "name": "GCP_PROJECT_ID",
                            "value": "$GCP_PROJECT_ID"
                        },
                        {
                            "name": "SITE_KEY",
                            "value": "$SITEKEY_ALWAYS_1"
                        }
                    ],
                    "apiProducts": [
                        "RecaptchaEnterprise"
                    ],
                    "callbackUrl": "",
                    "scopes": []
                },
                {
                    "name": "app-recaptcha-enterprise-always0",
                    "attributes": [
                        {
                            "name": "GCP_PROJECT_ID",
                            "value": "$GCP_PROJECT_ID"
                        },
                        {
                            "name": "SITE_KEY",
                            "value": "$SITEKEY_ALWAYS_0"
                        }
                    ],
                    "apiProducts": [
                        "RecaptchaEnterprise"
                    ],
                    "callbackUrl": "",
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
}

######################################
### function: set_recaptcha_config ###
######################################
set_recaptcha_config() {

    # Copy AM policy template
    cp "$SCRIPTPATH"/templates/AM-SetReCaptchaMock.template.xml "$SCRIPTPATH"/sf-recaptcha-enterprise-v1/sharedflowbundle/policies/AM-SetReCaptchaMock.xml

    # replace reCAPTCHA tag in AM policy
    sed -i.bak "s|@IsReCaptchaMockEnabled@|$1|" "$SCRIPTPATH"/sf-recaptcha-enterprise-v1/sharedflowbundle/policies/AM-SetReCaptchaMock.xml

    # remove .bak files
    rm "$SCRIPTPATH"/sf-recaptcha-enterprise-v1/sharedflowbundle/policies/AM-SetReCaptchaMock.xml.bak
}

### script execution starts here...

# Check for required variables
if [ -z "$GCP_PROJECT" ]; then
  echo "The required env variable GCP_PROJECT is missing";
  exit 1
fi

# Manage optional variables
GCP_REGION=${GCP_REGION:-europe-west1}
timestamp=$(date '+%s')
export PATH="$PATH:$SCRIPTPATH/../../tools/apigee-sackmesser/bin"

# default value for reCAPTCHA mock mode (default is 'true')
DEFAULT_IS_RECAPTCHA_MOCK_ENABLED=true

# is reCAPTCHA mock enabled (=true) or not (=false)
IS_RECAPTCHA_MOCK_ENABLED="${IS_RECAPTCHA_MOCK_ENABLED:-"$DEFAULT_IS_RECAPTCHA_MOCK_ENABLED"}"

# set reCAPTCHA config
set_recaptcha_config "$IS_RECAPTCHA_MOCK_ENABLED"

echo "[INFO] Deploying reCAPTCHA enterprise reference to Google API (For X/hybrid)"
APIGEE_TOKEN=$(gcloud auth print-access-token);

## Generate Service Account for Apigee shared flow
gcloud iam service-accounts create apigee-recaptcha-enterprise-sa \
--project "$GCP_PROJECT" || true

# Create the service account that is used to invoke the Google reCAPTCHA enterprise endpoint
gcloud projects add-iam-policy-binding "$GCP_PROJECT" \
    --member="serviceAccount:apigee-recaptcha-enterprise-sa@$GCP_PROJECT.iam.gserviceaccount.com" \
    --role="roles/recaptchaenterprise.agent"

# If reCAPTCHA mock is enabled
if [ -z "$IS_RECAPTCHA_MOCK_ENABLED" ] || [ "$IS_RECAPTCHA_MOCK_ENABLED" = "true" ];then

    # generate edge.json file
    generate_edge_mock_json "$APIGEE_X_ENV"

    set_functional_test_env_var "$timestamp"

    # deploy Apigee sharedflow
    sackmesser deploy --googleapi \
        -o "$APIGEE_X_ORG" \
        -e "$APIGEE_X_ENV" \
        -t "$APIGEE_TOKEN" \
        -h "$APIGEE_X_HOSTNAME" \
        -d "$SCRIPTPATH"/sf-recaptcha-enterprise-v1 \
        --deployment-sa apigee-recaptcha-enterprise-sa@"$GCP_PROJECT".iam.gserviceaccount.com

    # deploy Apigee artifacts: proxy, developer, app, product
    sackmesser deploy --googleapi \
        -o "$APIGEE_X_ORG" \
        -e "$APIGEE_X_ENV" \
        -t "$APIGEE_TOKEN" \
        -h "$APIGEE_X_HOSTNAME" \
        -d "$SCRIPTPATH"/data-proxy-v1

    # set developer app ('app-recaptcha-enterprise') credentials
    curl --fail --silent -X POST \
        -H "Authorization: Bearer $APIGEE_TOKEN" -H "Content-Type:application/json" \
        --data "{ \"consumerKey\": \"$TEST_APP_CONSUMER_KEY\", \"consumerSecret\": \"$TEST_APP_CONSUMER_SECRET\" }" \
        https://apigee.googleapis.com/v1/organizations/"$APIGEE_X_ORG"/developers/janedoe@example.com/apps/app-recaptcha-enterprise/keys/create

    # Set Recaptcha Enterprise product for developer app 'app-recaptcha-enterprise'
    curl --fail --silent -X POST \
        -H "Authorization: Bearer $APIGEE_TOKEN" -H "Content-Type:application/json" \
        --data "{ \"apiProducts\": [\"RecaptchaEnterprise\"] }" \
        https://apigee.googleapis.com/v1/organizations/"$APIGEE_X_ORG"/developers/janedoe@example.com/apps/app-recaptcha-enterprise/keys/"$TEST_APP_CONSUMER_KEY"

    
    cd "$SCRIPTPATH" && npm i --no-fund && TEST_HOST="$APIGEE_X_HOSTNAME" npm run test

else

    # Generate 2 reCAPTCHA sitekeys: - Always 1 (score: 1) & Always 0 (score: 0)
    TMP0=$(gcloud recaptcha keys create --testing-score=0.0 --web --allow-all-domains --display-name="Always 0" --integration-type=score --format=json | jq -r .name)
    SITEKEY_ALWAYS_0=$(echo "$TMP0" | cut -d'/' -f 4)
    
    TMP1=$(gcloud recaptcha keys create --testing-score=1.0 --web --allow-all-domains --display-name="Always 1" --integration-type=score --format=json | jq -r .name)
    SITEKEY_ALWAYS_1=$(echo "$TMP1" | cut -d'/' -f 4)

    # Get the current project Id
    GCP_PROJECT_ID=$(gcloud config get-value project)

    # generate edge.json file
    generate_edge_json "$APIGEE_X_ENV" "$GCP_PROJECT_ID" "$SITEKEY_ALWAYS_1" "$SITEKEY_ALWAYS_0"

    # deploy Apigee sharedflow
    sackmesser deploy --googleapi \
        -o "$APIGEE_X_ORG" \
        -e "$APIGEE_X_ENV" \
        -t "$APIGEE_TOKEN" \
        -h "$APIGEE_X_HOSTNAME" \
        -d "$SCRIPTPATH"/sf-recaptcha-enterprise-v1 \
        --deployment-sa apigee-recaptcha-enterprise-sa@"$GCP_PROJECT".iam.gserviceaccount.com

    # deploy Apigee artifacts: proxy, developer, app, product
    sackmesser deploy --googleapi \
        -o "$APIGEE_X_ORG" \
        -e "$APIGEE_X_ENV" \
        -t "$APIGEE_TOKEN" \
        -h "$APIGEE_X_HOSTNAME" \
        -d "$SCRIPTPATH"/data-proxy-v1

    # deploy an api proxy acting as a simple web page that can retrieve a reCAPTCHA token
    sackmesser deploy --googleapi \
        -o "$APIGEE_X_ORG" \
        -e "$APIGEE_X_ENV" \
        -t "$APIGEE_TOKEN" \
        -h "$APIGEE_X_HOSTNAME" \
        -d "$SCRIPTPATH"/deliver-token-v1

    echo "no tests run for custom reCAPTCHA enterprise configuration."

fi
