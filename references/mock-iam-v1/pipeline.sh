#!/bin/sh

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

