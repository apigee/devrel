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

npm install

node index.js --oas=./test/oas/apigeemock-v2.yaml --basepath /mock/v2 --name apigeemock-v2 --envs test2 --out ./test/out
node index.js --oas=./test/oas/apigeemock-v3.yaml --basepath /mock/v3 --name apigeemock-v3 --envs test2 --out ./test/out

diff ./test/out/src/main/apigee/apiproxies/apigeemock-v2/proxy.yaml ./test/apiproxies/apigeemock-v2/proxy.yaml
diff ./test/out/src/main/apigee/apiproxies/apigeemock-v3/proxy.yaml ./test/apiproxies/apigeemock-v3/proxy.yaml
