#!/bin/sh

set -e


# Ask for input parameters if they are not set

[ -z "$PROXY" ] && read -p "Proxy Name: " PROXY
[ -z "$VERSION" ] && read -p "Proxy Version: " VERSION
[ -z "$VHOST" ] && read -p "Virtual Host: " VERSION
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
