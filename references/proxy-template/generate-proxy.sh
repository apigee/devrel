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
[ -z "$VHOST" ]     && printf "Virtual Host: "  && read -r VHOST
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
    APIGEETOOL_DEPLOY_TARGETSERVER_SSLOPTION="--targetSSL true"
else
    APIGEETOOL_DEPLOY_TARGETSERVER_SSLOPTION=""
fi

# set target server name
TARGET_SERVER_NAME="ts-$TARGET_HOST-$TARGET_PORT"

# Copy template and replace variables

cp -r ./template-v1 ./"$PROXY"-"$VERSION"
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

rm ./"$PROXY"-"$VERSION"/apiproxy/proxies/default.xml.bak
rm ./"$PROXY"-"$VERSION"/package.json.bak
rm ./"$PROXY"-"$VERSION"/test/features/step_definitions/init.js.bak
rm ./"$PROXY"-"$VERSION"/test/features/TargetServer.feature.bak
rm ./"$PROXY"-"$VERSION"/apiproxy/targets/default.xml.bak

export APIGEETOOL_DEPLOY_TARGETSERVER_SSLOPTION
export TARGET_HOST
export TARGET_PORT
export TARGET_SERVER_NAME

echo "Complete Proxy Generation for $PROXY-$VERSION"
