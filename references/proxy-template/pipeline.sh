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

SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT")

# clean up
rm -rf example-v1

# deploy shared flows 
sh $SCRIPTPATH/../common-shared-flows/deploy-all.sh

# generate proxy
PROXY=example VERSION=v1 VHOST=secure TARGETURL=https://httpbin.org/get sh ./generate-proxy.sh

# deploy generated proxy
npm run deploy --prefix ./example-v1

# run tests
npm test --prefix ./example-v1
