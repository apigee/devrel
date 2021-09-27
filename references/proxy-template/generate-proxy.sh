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

# Ask for input parameters if they are not set

[ -z "$PROXY" ]     && printf "Proxy Name: "    && read -r PROXY
[ -z "$VERSION" ]   && printf "Proxy Version: " && read -r VERSION
[ -z "$VHOST" ]     && printf "Virtual Host (Edge only): "  && read -r VHOST
[ -z "$TARGET_URL" ] && printf "Target Server URL: "    && read -r TARGET_URL

# Abort if directory exists

[ -d ./"$PROXY"-"$VERSION" ] && echo "Proxy exists - aborting." && exit

# Extract domain name from URL using sed
# extract the protocol
TARGET_PROTOCOL="$(echo "$TARGET_URL" | grep :// | sed -e's,^\(.*://\).*,\1,g')"
# remove the protocol -- updated
url=$(echo "$TARGET_URL" | sed -e s,"$TARGET_PROTOCOL",,g)
# extract the user (if any)
user="$(echo "$url" | grep @ | cut -d@ -f1)"
# extract the host and port -- updated
hostport=$(echo "$url" | sed -e s,"$user"@,,g | cut -d/ -f1)
# by request host without port
TARGET_HOST="$(echo "$hostport" | sed -e 's,:.*,,g')"
# by request - try to extract the port
TARGET_PORT="$(echo "$hostport" | sed -e 's,^.*:,:,g' -e 's,.*:\([0-9]*\).*,\1,g' -e 's,[^0-9],,g')"
# extract the path (if any) that defines the proxy path
PROXY_PATH="/$(echo "$url" | grep / | cut -d/ -f2-)"

if [ -z "$TARGET_PORT" ] && [ "$TARGET_PROTOCOL" = "https://" ]
then
    TARGET_PORT="443"
elif [ -z "$TARGET_PORT" ] && [ "$TARGET_PROTOCOL" = "http://" ]
then
    TARGET_PORT="80"
fi

# based on the target server protocol, enable SSL or not
if [ "$TARGET_PROTOCOL" = "https://" ]
then
    TARGET_SSL="true"
else
    TARGET_SSL="false"
fi

# set target server name
TARGET_SERVER_NAME="ts-$TARGET_HOST-$TARGET_PORT"

# Copy proxy template and replace variables
cp -r ./template-v1 ./"$PROXY"-"$VERSION"
mv ./"$PROXY"-"$VERSION"/apiproxy/apigee-v1.xml ./"$PROXY"-"$VERSION"/apiproxy/"$PROXY"-"$VERSION".xml
sed -i.bak "s|@ProxyName@|$PROXY|" ./"$PROXY"-"$VERSION"/apiproxy/"$PROXY"-"$VERSION".xml
sed -i.bak "s|@Version@|$VERSION|" ./"$PROXY"-"$VERSION"/apiproxy/"$PROXY"-"$VERSION".xml
sed -i.bak "s|@Basepath@|$PROXY|" ./"$PROXY"-"$VERSION"/apiproxy/proxies/default.xml
sed -i.bak "s|@VirtualHost@|$VHOST|" ./"$PROXY"-"$VERSION"/apiproxy/proxies/default.xml
sed -i.bak "s|@Proxy@|$PROXY|" ./"$PROXY"-"$VERSION"/package.json
sed -i.bak "s|@Proxy@|$PROXY|" ./"$PROXY"-"$VERSION"/test/features/step_definitions/init.js
sed -i.bak "s|@Version@|$VERSION|" ./"$PROXY"-"$VERSION"/apiproxy/proxies/default.xml
sed -i.bak "s|@Version@|$VERSION|" ./"$PROXY"-"$VERSION"/package.json
sed -i.bak "s|@Version@|$VERSION|" ./"$PROXY"-"$VERSION"/test/features/step_definitions/init.js
sed -i.bak "s|@ProxyPath@|$PROXY_PATH|" ./"$PROXY"-"$VERSION"/apiproxy/proxies/default.xml
sed -i.bak "s|@ProxyPath@|$PROXY_PATH|" ./"$PROXY"-"$VERSION"/test/features/TargetServer.feature
sed -i.bak "s|@TargetServerName@|$TARGET_SERVER_NAME|" ./"$PROXY"-"$VERSION"/apiproxy/targets/default.xml

if [ -z "$1" ] || [ "$1" = "--apigeeapi" ];then

    # create target server if does not exist
    response=$(curl -X GET \
        -u "$APIGEE_USER":"$APIGEE_PASS" -H "Accept: application/json" -w "%{http_code}" \
        https://api.enterprise.apigee.com/v1/organizations/"$APIGEE_ORG"/environments/"$APIGEE_ENV"/targetservers/"$TARGET_SERVER_NAME")

        if [ "$( printf '%s' "$response" | grep -c 404 )" -ne 0  ]; then

            # Copy the target server's template file and replace variables
            cp ./edge.template.json ./"$PROXY"-"$VERSION"/edge.json
            sed -i.bak "s/@ENV_NAME@/$APIGEE_ENV/g" ./"$PROXY"-"$VERSION"/edge.json
            sed -i.bak "s/@TargetSSL@/$TARGET_SSL/g" ./"$PROXY"-"$VERSION"/edge.json
            sed -i.bak "s/@TargetHost@/$TARGET_HOST/g" ./"$PROXY"-"$VERSION"/edge.json
            sed -i.bak "s/@TargetServerName@/$TARGET_SERVER_NAME/g" ./"$PROXY"-"$VERSION"/edge.json
            sed -i.bak "s/@TargetPort@/$TARGET_PORT/g" ./"$PROXY"-"$VERSION"/edge.json

            rm ./"$PROXY"-"$VERSION"/edge.json.bak
            echo "Complete TargetServer ($TARGET_SERVER_NAME) Generation for $PROXY-$VERSION"
        fi
fi

if [ -z "$1" ] || [ "$1" = "--googleapi" ];then

    # get apigee token
    APIGEE_TOKEN=$(gcloud auth print-access-token);

    # create target server if does not exist
    response=$(curl -X GET \
        -H "Authorization: Bearer $APIGEE_TOKEN" -H "Accept: application/json" -w "%{http_code}" \
        https://apigee.googleapis.com/v1/organizations/"$APIGEE_X_ORG"/environments/"$APIGEE_X_ENV"/targetservers/"$TARGET_SERVER_NAME")

        if [ "$( printf '%s' "$response" | grep -c 404 )" -ne 0  ]; then

            # Copy the target server's template file and replace variables
            cp ./edge.template.json ./"$PROXY"-"$VERSION"/edge.json
            sed -i.bak "s/@ENV_NAME@/$APIGEE_X_ENV/g" ./"$PROXY"-"$VERSION"/edge.json
            sed -i.bak "s/@TargetSSL@/$TARGET_SSL/g" ./"$PROXY"-"$VERSION"/edge.json
            sed -i.bak "s/@TargetHost@/$TARGET_HOST/g" ./"$PROXY"-"$VERSION"/edge.json
            sed -i.bak "s/@TargetServerName@/$TARGET_SERVER_NAME/g" ./"$PROXY"-"$VERSION"/edge.json
            sed -i.bak "s/@TargetPort@/$TARGET_PORT/g" ./"$PROXY"-"$VERSION"/edge.json

            rm ./"$PROXY"-"$VERSION"/edge.json.bak
            echo "Complete TargetServer ($TARGET_SERVER_NAME) Generation for $PROXY-$VERSION"
        fi
fi

rm ./"$PROXY"-"$VERSION"/apiproxy/"$PROXY"-"$VERSION".xml.bak
rm ./"$PROXY"-"$VERSION"/apiproxy/proxies/default.xml.bak
rm ./"$PROXY"-"$VERSION"/package.json.bak
rm ./"$PROXY"-"$VERSION"/test/features/step_definitions/init.js.bak
rm ./"$PROXY"-"$VERSION"/test/features/TargetServer.feature.bak
rm ./"$PROXY"-"$VERSION"/apiproxy/targets/default.xml.bak

echo "Complete Proxy Generation for $PROXY-$VERSION"