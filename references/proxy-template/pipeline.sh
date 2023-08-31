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

SCRIPTPATH="$( cd "$(dirname "$0")" || exit >/dev/null 2>&1 ; pwd -P )"

# default proxy name and version
PROXY=example
VERSION=v1

# default target server URL
DEFAULT_TARGET_URL=https://mocktarget.apigee.net/echo

# default Virtual Host
VHOST=secure

# set target URL that is used to configure a target server
TARGET_URL="${TARGET_URL:-"$DEFAULT_TARGET_URL"}"

if [ -z "$1" ] || [ "$1" = "--apigeeapi" ];then

    # deploy all common shared flows
    (cd "$SCRIPTPATH"/../common-shared-flows && sh deploy.sh all --apigeeapi --async)

    # clean up
    rm -rf "$SCRIPTPATH"/"$PROXY"-"$VERSION"

    # generate the proxy configuration
    echo "[INFO] Creating Proxy template and Target Server configuration"

    PROXY="$PROXY" \
    VERSION="$VERSION" \
    VHOST="$VHOST" \
    TARGET_URL="$TARGET_URL" \
    "$SCRIPTPATH"/generate-proxy.sh --apigeeapi

    echo "[INFO] Deploying Proxy template to Apigee API (For Edge)"

    # deploy Apigee artifacts: proxy and target server
    sackmesser deploy --apigeeapi \
    -o "$APIGEE_ORG" \
    -e "$APIGEE_ENV" \
    -u "$APIGEE_USER" \
    -p "$APIGEE_PASS" \
    -d "$SCRIPTPATH"/"$PROXY"-"$VERSION"

    # run tests
    TEST_HOST="$APIGEE_ORG-$APIGEE_ENV.apigee.net" npm test --prefix ./"$PROXY"-"$VERSION"
fi

if [ -z "$1" ] || [ "$1" = "--googleapi" ];then

    # deploy all common shared flows
    (cd "$SCRIPTPATH"/../common-shared-flows && sh deploy.sh all --googleapi --async)

    # clean up
    rm -rf "$SCRIPTPATH"/"$PROXY"-"$VERSION"

    # generate the proxy configuration
    echo "[INFO] Creating Proxy template and Target Server configuration"

    PROXY="$PROXY" \
    VERSION="$VERSION" \
    VHOST="$VHOST" \
    TARGET_URL="$TARGET_URL" \
    "$SCRIPTPATH"/generate-proxy.sh --googleapi

    echo "[INFO] Deploying Proxy Template to Google API (For X/hybrid)"

    # get apigee token
    APIGEE_TOKEN="$(gcloud config config-helper --force-auth-refresh --format json | jq -r '.credential.access_token')";

    # deploy Apigee artifacts: proxy and target server
    sackmesser deploy --googleapi \
    -o "$APIGEE_X_ORG" \
    -e "$APIGEE_X_ENV" \
    -t "$APIGEE_TOKEN" \
    -h "$APIGEE_X_HOSTNAME" \
    -d "$SCRIPTPATH"/"$PROXY"-"$VERSION"

    # run tests
    TEST_HOST="$APIGEE_X_HOSTNAME" npm test --prefix ./"$PROXY"-"$VERSION"
fi