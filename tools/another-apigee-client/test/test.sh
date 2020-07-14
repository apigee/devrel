#!/bin/sh

set -e

# Tear down
docker rm -f aac-tests

# Set up
docker run -itd --name aac-tests alpine 
docker exec -it aac-tests apk add curl jq
docker cp . aac-tests:/root

# First time token
docker exec -e APIGEE_USER -e APIGEE_PASS -it aac-tests sh /root/aac-token

# Second time token
docker exec -e APIGEE_USER -e APIGEE_PASS -it aac-tests sh /root/aac-token

# Expired access token
docker exec -e APIGEE_USER -e APIGEE_PASS -it aac-tests sh /root/test/inject-expired-token.sh access
docker exec -e APIGEE_USER -e APIGEE_PASS -it aac-tests sh /root/aac-token

# Expired refresh token
#docker exec -e APIGEE_USER -e APIGEE_PASS -it aac-tests sh /root/test/inject-expired-token.sh refresh
#docker exec -e APIGEE_USER -e APIGEE_PASS -it aac-tests sh /root/aac-token
