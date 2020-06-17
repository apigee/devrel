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

[ -z "$PROXY" ] && read -p "Proxy Name: " PROXY
[ -z "$VERSION" ] && read -p "Proxy Version: " VERSION
[ -z "$VHOST" ] && read -p "Virtual Host: " VHOST
[ -z "$TARGETURL" ] && read -p "Target URL: " TARGETURL

# Abort if directory exists

[[ -d ./$PROXY-$VERSION ]] && echo "Proxy exists - aborting." && exit

# Copy template and replace variables

cp -r ./template-v1 ./$PROXY-$VERSION
sed -i "s|@Basepath@|$PROXY|" ./$PROXY-$VERSION/apiproxy/proxies/default.xml
sed -i "s|@VirtualHost@|$VHOST|" ./$PROXY-$VERSION/apiproxy/proxies/default.xml
sed -i "s|@Proxy@|$PROXY|" ./$PROXY-$VERSION/package.json
sed -i "s|@Proxy@|$PROXY|" ./$PROXY-$VERSION/test/features/step_definitions/init.js
sed -i "s|@Version@|$VERSION|" ./$PROXY-$VERSION/apiproxy/proxies/default.xml
sed -i "s|@Version@|$VERSION|" ./$PROXY-$VERSION/package.json
sed -i "s|@Version@|$VERSION|" ./$PROXY-$VERSION/test/features/step_definitions/init.js
sed -i "s|@TargetURL@|$TARGETURL|" ./$PROXY-$VERSION/apiproxy/targets/default.xml

echo "Complete Proxy Generation for $PROXY-$VERSION"
