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

# Abort if TARGET_SERVER_NAME or TARGET_PATH have not been set

if [ -z "$TARGET_SERVER_NAME" ] || [ -z "$TARGET_PATH" ]; then
    echo "Target server environment variables not set: please set TARGET_URL and 'source ./set-targetserver-envs.sh'." && exit
fi

# Ask for input parameters if they are not set

[ -z "$PROXY" ]     && printf "Proxy Name: "    && read -r PROXY
[ -z "$VERSION" ]   && printf "Proxy Version: " && read -r VERSION
[ -z "$VHOST" ]     && printf "Virtual Host: "  && read -r VHOST

# Abort if directory exists

[ -d ./"$PROXY"-"$VERSION" ] && echo "Proxy exists - aborting." && exit

# Copy template and replace variables

cp -r ./template-v1 ./"$PROXY"-"$VERSION"
sed -i.bak "s|@Basepath@|$PROXY|" ./"$PROXY"-"$VERSION"/apiproxy/proxies/default.xml
sed -i.bak "s|@VirtualHost@|$VHOST|" ./"$PROXY"-"$VERSION"/apiproxy/proxies/default.xml
sed -i.bak "s|@Proxy@|$PROXY|" ./"$PROXY"-"$VERSION"/package.json
sed -i.bak "s|@Proxy@|$PROXY|" ./"$PROXY"-"$VERSION"/test/features/step_definitions/init.js
sed -i.bak "s|@Version@|$VERSION|" ./"$PROXY"-"$VERSION"/apiproxy/proxies/default.xml
sed -i.bak "s|@Version@|$VERSION|" ./"$PROXY"-"$VERSION"/package.json
sed -i.bak "s|@Version@|$VERSION|" ./"$PROXY"-"$VERSION"/test/features/step_definitions/init.js
sed -i.bak "s|@TargetPath@|$TARGET_PATH|" ./"$PROXY"-"$VERSION"/apiproxy/proxies/default.xml
sed -i.bak "s|@TargetPath@|$TARGET_PATH|" ./"$PROXY"-"$VERSION"/test/features/TargetServer.feature
sed -i.bak "s|@TargetServerName@|$TARGET_SERVER_NAME|" ./"$PROXY"-"$VERSION"/apiproxy/targets/default.xml

rm ./"$PROXY"-"$VERSION"/apiproxy/proxies/default.xml.bak
rm ./"$PROXY"-"$VERSION"/package.json.bak
rm ./"$PROXY"-"$VERSION"/test/features/step_definitions/init.js.bak
rm ./"$PROXY"-"$VERSION"/test/features/TargetServer.feature.bak
rm ./"$PROXY"-"$VERSION"/apiproxy/targets/default.xml.bak

echo "Complete Proxy Generation for $PROXY-$VERSION"
