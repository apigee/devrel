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

# Ask for input parameter (target url) if it is not set

[ -z "$TARGET_URL" ] && printf "Target URL: "    && read -r TARGET_URL

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
# extract the path (if any)
TARGET_PATH="/$(echo "$url" | grep / | cut -d/ -f2-)"

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
    APIGEETOOL_DEPLOY_TARGETSERVER_SSLOPTION="--targetSSL true"
else
    TARGET_SSL="false"
    APIGEETOOL_DEPLOY_TARGETSERVER_SSLOPTION=""
fi

# set target server name
TARGET_SERVER_NAME="ts-$TARGET_HOST-$TARGET_PORT"

export APIGEETOOL_DEPLOY_TARGETSERVER_SSLOPTION
export TARGET_HOST
export TARGET_PATH
export TARGET_PORT
export TARGET_SERVER_NAME
export TARGET_SSL

echo "Target Server environment variables have been set."
