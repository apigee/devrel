#!/bin/sh
# Copyright 2021 Google LLC
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
# shellcheck disable=SC2230

###
# Apigee OpenLegacy Kickstart (aok) CLI
###

set -e

SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT")

###
# Check for required variables
###

if [ -z "$OPENLEGACY_APIKEY"   ] || \
   [ -z "$OPENLEGACY_HOST"     ] || \
   [ -z "$OPENLEGACY_USER"     ] || \
   [ -z "$OPENLEGACY_PASS"     ] || \
   [ -z "$OPENLEGACY_CODEPAGE" ] || \
   [ -z "$APIGEE_USER"         ] || \
   [ -z "$APIGEE_PASS"         ] || \
   [ -z "$APIGEE_ORG"          ] || \
   [ -z "$APIGEE_ENV"          ] || \
   [ -z "$GCP_PROJECT"         ]; then
  echo "A required variable is missing"; 
  exit 1
fi

###
# Manage optional variables
###

GCP_REGION=${GCP_REGION:-europe-west1}

###
# Check for required tools on path
###

for TOOL in unzip ol gcloud jq node npm; do
  if ! which $TOOL > /dev/null; then
    echo "Please ensure $TOOL is installed and on your PATH"
    exit 1
  fi
done

###
# Configure OpenLegacy
###

ol login --api-key "$OPENLEGACY_APIKEY"
ol create module --connector as400-pcml aok-module
cp "$SCRIPTPATH"/../res/getcst.pcml aok-module/
(cd aok-module/ && ol add --source-path getcst.pcml --host "$OPENLEGACY_HOST" --code-page "$OPENLEGACY_CODEPAGE" --user "$OPENLEGACY_USER" --password "$OPENLEGACY_PASS")
(cd aok-module/ && ol push module)
ol create project aok-project --modules aok-module

###
# Push OpenLegacy Image
###

gcloud services enable containerregistry.googleapis.com run.googleapis.com
gcloud auth configure-docker -q

cat > Dockerfile <<EOF
FROM openlegacy/as400-rpc:1.1.2
RUN mkdir -p /tmp/data
RUN echo '{ \
  "source-provider": { \
    "type": "HUB", \
    "hub": { \
      "project-name": "aok-project", \
      "api-key": "$OPENLEGACY_APIKEY" \
    } \
  } \
}' > /tmp/data/config.json
EOF

docker build -t gcr.io/"$GCP_PROJECT"/aok-image:latest .
docker push gcr.io/"$GCP_PROJECT"/aok-image:latest


###
# Deploy OpenLegacy
###

gcloud run deploy aok-service --image gcr.io/"$GCP_PROJECT"/aok-image:latest --platform managed --region "$GCP_REGION" -q
TARGET_URL=$(gcloud run services describe aok-service --platform managed --region "$GCP_REGION" --format json | jq -r '.status.url')

###
# Get OpenLegacy OpenAPI Specification
###

curl -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  "$TARGET_URL/openapi/openapi.yaml" \
  -o openapi.yaml

###
## Generate Service Account for Apigee to call Cloud Run
###

gcloud iam service-accounts create aok-sa --project "$GCP_PROJECT" || true
gcloud iam service-accounts keys create credentials.json --iam-account aok-sa@"$GCP_PROJECT".iam.gserviceaccount.com
gcloud run services add-iam-policy-binding aok-service --region "$GCP_REGION" --member serviceAccount:aok-sa@"$GCP_PROJECT".iam.gserviceaccount.com --role roles/run.invoker --platform managed

###
# Create Apigee Cache for Service Account
###

npx apigeetool createcache -u "$APIGEE_USER" -p "$APIGEE_PASS" -o "$APIGEE_ORG" -e "$APIGEE_ENV" -z gcp-tokens

###
# Push service account json to KVM
###

GCP_SA_KEY=$(jq '. | tostring' < "./credentials.json")
curl -XPOST -s -u "$APIGEE_USER:$APIGEE_PASS" "https://api.enterprise.apigee.com/v1/o/$APIGEE_ORG/e/$APIGEE_ENV/keyvaluemaps" \
  -H 'Content-Type: application/json; charset=utf-8' \
  --data-binary @- > /dev/null << EOF
{
  "name": "aok-service-accounts",
  "encrypted": "true",
  "entry": [
    {
      "name": "cloud-run",
      "value": $GCP_SA_KEY
    }
  ]
}
EOF

###
# Deploy Shared Flow to manage JWT token to OpenLegacy
###

npm run deploy --prefix "$SCRIPTPATH"/../../../references/gcp-sa-auth-shared-flow

###
# Generate the Apigee Proxy
###

cp -r "$SCRIPTPATH"/../res/proxy aok-v1
sed -i.bak "s|@TargetURL@|$TARGET_URL|" ./aok-v1/apiproxy/targets/default.xml
sed -i.bak "s|@TargetURL@|$TARGET_URL|" ./aok-v1/apiproxy/policies/AM.GCPAudience.xml
rm ./aok-v1/apiproxy/targets/default.xml.bak ./aok-v1/apiproxy/policies/AM.GCPAudience.xml.bak

###
# deploy apigee proxy
###

npm run deploy --prefix ./aok-v1

###
# Create Apigee Developer, App and Product
###

npx apigeetool createProduct -u "$APIGEE_USER" -p "$APIGEE_PASS" -o "$APIGEE_ORG" --productName "ApigeeOpenLegacy" --proxies "aok-v1" --environments "test"
npx apigeetool createDeveloper -u "$APIGEE_USER" -p "$APIGEE_PASS" -o "$APIGEE_ORG" --email "aok@example.com" --userName "aok@example.com" --firstName "AOK" --lastName "Developer"
npx apigeetool createApp -u "$APIGEE_USER" -p "$APIGEE_PASS" -o "$APIGEE_ORG" --email "aok@example.com" --apiProducts "ApigeeOpenLegacy" --name "AOKApp" > app.json

APIKEY=$(jq '.credentials[0].consumerKey' -r < app.json )
echo "APIKEY is $APIKEY"
sed -i.bak "s|@APIKEY@|$APIKEY|" ./aok-v1/test/features/step_definitions/init.js
rm ./aok-v1/test/features/step_definitions/init.js.bak

sleep 60 # service account can take up to 60 seconds to propogate

###
# run some smoke tests
###

APIKEY=APIKEY npm test --prefix ./aok-v1

### print result
echo "Successfully Apigee OpenLegacy Kickstarter. API key is $APIKEY"
