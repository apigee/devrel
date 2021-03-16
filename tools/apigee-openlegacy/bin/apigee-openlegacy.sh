#!/bin/sh

###
# Apigee OpenLegacy Quickstart CLI
###

set -e

###
# Check for required variables
###

if [ \
    -z "$OPENLEGACY_APIKEY" -o \
    -z "$OPENLEGACY_HOST" -o \
    -z "$OPENLEGACY_USER" -o \
    -z "$OPENLEGACY_PASS" -o \
    -z "$OPENLEGACY_CODEPAGE" -o \
    -z "$APIGEE_USER" -o \
    -z "$APIGEE_PASS" -o \
    -z "$APIGEE_ORG" -o \
    -z "$APIGEE_ENV" -o \
    -z "$GCP_PROJECT" \
  ]; then
  echo "A required variable is missing"; 
  exit 1
fi

###
# Check for required tools on path
###

if ! which mvn > /dev/null; then
  echo "Please ensure mvn is installed and on your PATH"
fi
if ! which ol > /dev/null; then
  echo "Please ensure ol is installed and on your PATH"
fi
if ! which gcloud > /dev/null; then
  echo "Please ensure gcloud is installed and on your PATH"
fi
if ! which oas-to-am > /dev/null; then
  echo "Please ensure oas-to-am is installed and on your PATH"
fi

###
# Create a temporary build directory
###

rm -r target/
mkdir -p target/

###
# Configure OpenLegacy
###

ol login --api-key "$OPENLEGACY_APIKEY"
ol create module --connector IBMi-as400-pcml --name apigee-openlegacy-kickstart-module
cp getcst.pcml apigee-openlegacy-kickstart-module/
ol add --source-path getcst.pcml --host "$OPENLEGACY_HOST" --code-page "$OPENLEGACY_CODEPAGE" --user "$OPENLEGACY_USER" --password "$OPENLEGACY_PASS"
ol push module
MODULE_ID=$(./ol/bin/ol modules | grep "testforapigee" | awk '{ print $1 }')
ol create project --name apigee-openlegacy-kickstart-project --modules "$MODULE_ID"

###
# Push OpenLegacy Image
###

gcloud services enable containerregistry.googleapis.com
gcloud auth configure-docker

cat > /tmp/Dockerfile <<EOF
FROM openlegacy/as400-rpc
RUN echo "{
  "source-provider": {
    "type": "HUB",
    "hub": {
      "project-id": "$PROJECT_ID",
      "api-key": "$OPENLEGACY_APIKEY"
    }
  }
}" > /app/config/config.json
EOF

docker build -t gcr.io/$GCP_PROJECT/apigee-openlegacy:v1 /tmp

###
# Deploy OpenLegacy
###

gcloud run deploy --image gcr.io/$GCP_PROJECT/apigee-openlegacy:v1 --platform managed
FUNCTION_URL=$()

###
# Get OpenLegacy OpenAPI Specification
###

curl -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  "$FUNCTION_URL" \
  -o /tmp/openapi.json

###
## Generate Service Account for Apigee to call Cloud Run
###

gcloud iam service-accounts create cloud-invoke-test --project $GCP_PROJECT
gcloud iam service-accounts keys create credentials.json --iam-account cloud-invoke-test@PROJECTID.iam.gserviceaccount.com

# TODO Create Apigee Cache for Service Account
# TODO push service account json to KVM
# TODO deploy shared flow at ./references/gcp-sa-auth-shared-flow/ 

###
# generate apigee proxy
###

cp -r proxy target/proxy
SPEC=./target/openapi.json OPERATION=operationId oas-to-am > target/proxy/policies/Assign.OpenLegacy.xml

###
# deploy and test apigee
###

mvn clean install \
  -P"apigeeapi" \
  -Dpassword="${APIGEE_PASS}" \
  -Denv="${env.APIGEE_ENV}" \
  -Dusername="${APIGEE_USER}" \
  -Dorg="${env.APIGEE_ORG}"
