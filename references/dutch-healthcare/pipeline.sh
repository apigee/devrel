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

SCRIPTPATH=$( (cd "$(dirname "$0")" && pwd ))

APIGEE_TOKEN=$(gcloud auth print-access-token);
export APIGEE_TOKEN

# deploy shared flows
(cd "$SCRIPTPATH"/../common-shared-flows && sh deploy.sh all --googleapi --async)

ARGS=$*
SACK_ARGS="${ARGS:---googleapi}"

bash "$SCRIPTPATH"/../../tools/apigee-sackmesser/bin/sackmesser deploy \
  -d healthcare-mock-v1 "$SACK_ARGS"

bash "$SCRIPTPATH"/../../tools/apigee-sackmesser/bin/sackmesser deploy \
  -d healthcare-v1 "$SACK_ARGS"

npm i --no-fund --prefix healthcare-v1
TEST_BASEPATH='/healthcare/v1' TEST_HOST="$APIGEE_X_HOSTNAME" npm test --prefix healthcare-v1
