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

# TODO figure out how to move this to apigee/devrel repo
# See https://github.com/apigee/devrel/issues/76
docker pull ghcr.io/danistrebel/devrel/jenkinsfile-runner:latest
docker tag ghcr.io/danistrebel/devrel/jenkinsfile-runner:latest devrel/jenkinsfile-runner:latest

# because volume mounts don't work inside docker in docker without reference to the host file system
cat << EOF >> /tmp/Dockerfile-jenkins-cicd
FROM devrel/jenkinsfile-runner:latest
COPY ./airports-cicd-v1 /workspace
EOF
docker build -f /tmp/Dockerfile-jenkins-cicd -t devrel/jenkinsfile-runner-airports:latest .
rm /tmp/Dockerfile-jenkins-cicd

docker run \
  -e APIGEE_USER \
  -e APIGEE_PASS \
  -e APIGEE_ORG \
  -e GIT_BRANCH=nightly \
  -e AUTHOR_EMAIL="cicd@apigee.google.com" \
  -e JENKINS_ADMIN_PASS=password \
  -i devrel/jenkinsfile-runner-airports:latest

npm install --no-fund

API_NAME=airports-cicd-nightly

echo "Undeploying Proxy $API_NAME:"
curl -u "$APIGEE_USER:$APIGEE_PASS" -X DELETE "https://api.enterprise.apigee.com/v1/organizations/$APIGEE_ORG/environments/test/apis/$API_NAME/revisions/1/deployments"
echo "Deleting Proxy $API_NAME:"
curl -u "$APIGEE_USER:$APIGEE_PASS" -X DELETE "https://api.enterprise.apigee.com/v1/organizations/$APIGEE_ORG/apis/$API_NAME"
