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
export PATH="$PATH:$SCRIPTPATH/../../tools/apigee-sackmesser/bin"

# deploy Apigee API Proxy
sackmesser deploy --apigeeapi -o "$APIGEE_ORG" -e "$APIGEE_ENV" -u "$APIGEE_USER" -p "$APIGEE_PASS" -d "$SCRIPTPATH"

# execute integration tests
(cd "$SCRIPTPATH" npm install && TEST_HOST="$APIGEE_ORG-$APIGEE_ENV.apigee.net" npm run test)
