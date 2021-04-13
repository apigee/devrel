#!/bin/sh
# Copyright 2021 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# <http://www.apache.org/licenses/LICENSE-2.0>
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e
set -x

# clean up
rm -rf ../api_bundles

node ../bin/oas-apigee-mock generateApi oas-apigee-mock-orders -s orders.yaml

RESULT="$(diff -r ../api_bundles/ api_bundles/ )"
EXPECT=""

# assert that the result matches the expected bundle
if test "$RESULT" = "$EXPECT"; then
  echo "PASS"
else
  echo "FAIL"
fi

apigeetool deployproxy -u "$APIGEE_USER" -p "$APIGEE_PASS" -o "$APIGEE_ORG" -e "$APIGEE_ENV" -n oas-apigee-mock-orders -d ../api_bundles/oas-apigee-mock-orders -V

npm test