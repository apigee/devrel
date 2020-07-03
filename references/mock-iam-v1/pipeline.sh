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


# Run apickli against mock
npm install --prefix src
npm run deploy --prefix src

npm install --prefix test
MOCK=true npm test --prefix test

# Repeat tests against local Keycloak
docker rm -f some-keycloak
docker run --name=some-keycloak -e DB_VENDOR=h2 -e DB_ADDR= -e KEYCLOAK_USER=admin -e KEYCLOAK_PASSWORD=Password123 -p 8888:8080 -itd jboss/keycloak
echo "Waiting for Keycloak on port 8888"
while ! `curl --fail --silent http://localhost:8888/auth`; do sleep 1; echo -n "."; done
docker exec -it some-keycloak sh /opt/jboss/keycloak/bin/kcadm.sh config credentials --server http://localhost:8080/auth --realm master --user admin --password Password123
docker exec -it some-keycloak sh /opt/jboss/keycloak/bin/kcadm.sh update realms/master -s sslRequired=NONE
npm test --prefix test

