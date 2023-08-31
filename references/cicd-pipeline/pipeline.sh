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

set -e
SCRIPTPATH=$( (cd "$(dirname "$0")" && pwd ))

echo "[INFO] CICD Pipeline for Apigee X/hybrid (Cloud Build)"
BRANCH_NAME_X=devrel-cloudbuild
SUBSTITUTIONS_X="_INT_TEST_HOST=$APIGEE_X_HOSTNAME"
SUBSTITUTIONS_X="$SUBSTITUTIONS_X,_DEPLOYMENT_ORG=$APIGEE_X_ORG"
SUBSTITUTIONS_X="$SUBSTITUTIONS_X,_APIGEE_TEST_ENV=$APIGEE_X_ENV"
SUBSTITUTIONS_X="$SUBSTITUTIONS_X,_API_VERSION=google"
SUBSTITUTIONS_X="$SUBSTITUTIONS_X,_WORK_DIR=."
SUBSTITUTIONS_X="$SUBSTITUTIONS_X,BRANCH_NAME=$BRANCH_NAME_X"
gcloud builds submit --config="$SCRIPTPATH/ci-config/cloudbuild/cloudbuild.yaml" \
  --substitutions="$SUBSTITUTIONS_X"

echo "[INFO] CICD Pipeline for Apigee Edge (Cloud Build)"

BRANCH_NAME_EDGE=devrel-cloudbuild
SUBSTITUTIONS_EDGE="_INT_TEST_HOST=$APIGEE_ORG-$APIGEE_ENV.apigee.net"
SUBSTITUTIONS_EDGE="$SUBSTITUTIONS_EDGE,_DEPLOYMENT_ORG=$APIGEE_ORG"
SUBSTITUTIONS_X="$SUBSTITUTIONS_X,_WORK_DIR=."
SUBSTITUTIONS_EDGE="$SUBSTITUTIONS_EDGE,BRANCH_NAME=$BRANCH_NAME_EDGE"

gcloud builds submit --config="$SCRIPTPATH/ci-config/cloudbuild/cloudbuild.yaml" \
  --substitutions="$SUBSTITUTIONS_EDGE"

echo "[INFO] Build Jenkins File Runner Image"

docker build -f "$SCRIPTPATH/jenkins-build/Dockerfile" -t apigee/devrel-jenkins-base:latest "$SCRIPTPATH/jenkins-build"
docker build -f "$SCRIPTPATH/jenkins-build/jenkinsfile-runner/Dockerfile" --build-arg baseImage=apigee/devrel-jenkins-base --build-arg baseImageTag=latest -t apigee/devrel-jenkinsfile:latest "$SCRIPTPATH/jenkins-build"

# because volume mounts don't work inside docker in docker without reference to the host file system
cat << EOF >  "$SCRIPTPATH/Dockerfile-jenkins-cicd"
FROM apigee/devrel-jenkinsfile:latest
COPY --chown=jenkins  . /workspace
RUN cp /workspace/ci-config/jenkins/Jenkinsfile /workspace/Jenkinsfile
EOF
docker build -f  "$SCRIPTPATH/Dockerfile-jenkins-cicd" -t apigee/devrel-jenkinsfile-airports:latest  "$SCRIPTPATH"
rm  "$SCRIPTPATH/Dockerfile-jenkins-cicd"

echo "[INFO] CICD Pipeline for Apigee Edge (Jenkins)"
docker run \
  -e APIGEE_USER \
  -e APIGEE_PASS \
  -e APIGEE_ORG \
  -e APIGEE_TEST_ENV="$APIGEE_ENV" \
  -e APIGEE_PROD_ENV="$APIGEE_ENV" \
  -e TEST_HOST="$APIGEE_ORG-$APIGEE_ENV.apigee.net" \
  -e API_VERSION="apigee" \
  -e GIT_BRANCH=nightly \
  -e AUTHOR_EMAIL="cicd@apigee.google.com" \
  -e JENKINS_ADMIN_PASS="password" \
  -e WORK_DIR="." \
  apigee/devrel-jenkinsfile-airports:latest


echo "[INFO] CICD Pipeline for Apigee X (Jenkins)"

TOKEN="$(gcloud config config-helper --force-auth-refresh --format json | jq -r '.credential.access_token')"

docker run \
  -e APIGEE_USER="not-used" \
  -e APIGEE_PASS="not-used" \
  -e GCP_SA_AUTH="token" \
  -e APIGEE_TOKEN="$TOKEN" \
  -e APIGEE_ORG="$APIGEE_X_ORG" \
  -e APIGEE_TEST_ENV="$APIGEE_X_ENV" \
  -e APIGEE_PROD_ENV="$APIGEE_X_ENV" \
  -e TEST_HOST="$APIGEE_X_HOSTNAME" \
  -e API_VERSION="google" \
  -e GIT_BRANCH=nightly \
  -e AUTHOR_EMAIL="cicd@apigee.google.com" \
  -e JENKINS_ADMIN_PASS="password" \
  -e WORK_DIR="." \
  apigee/devrel-jenkinsfile-airports:latest
