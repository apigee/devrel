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
set -x

SCRIPTPATH="$( cd "$(dirname "$0")" || exit >/dev/null 2>&1 ; pwd -P )"

# default proxy name and version
PROXY=example 
VERSION=v1

# clean up
rm -rf "$PROXY"-"$VERSION"

# deploy all shared flows
(cd "$SCRIPTPATH"/../common-shared-flows && sh deploy.sh all --apigeeapi)

# set target server environment variables
DEFAULT_TARGET_URL=https://httpbin.org/get
export TARGET_URL="${TARGET_URL:-"$DEFAULT_TARGET_URL"}"

. "$SCRIPTPATH"/set-targetserver-envs.sh

# create target server if does not exist
response=$(curl -X GET \
    -u "$APIGEE_USER":"$APIGEE_PASS" -H "Accept: application/json" -w "%{http_code}" \
    https://api.enterprise.apigee.com/v1/organizations/"$APIGEE_ORG"/environments/"$APIGEE_ENV"/targetservers/"$TARGET_SERVER_NAME")

# generate proxy
PROXY=$PROXY VERSION=$VERSION VHOST=secure TARGET_PATH="$TARGET_PATH" TARGET_SERVER_NAME="$TARGET_SERVER_NAME" sh ./generate-proxy.sh

if [ "$( printf '%s' "$response" | grep -c 404 )" -ne 0  ]; then
    npm run deployTargetServer --prefix ./"$PROXY"-"$VERSION"
fi

# deploy generated proxy
npm run deployProxy --prefix ./"$PROXY"-"$VERSION"

# run tests
npm test --prefix ./"$PROXY"-"$VERSION"
