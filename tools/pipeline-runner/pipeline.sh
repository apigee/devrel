#!/bin/sh

# Copyright 2020 Google LLC
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

docker build -t apigee/devrel-local .

# run for all projects
docker run -v "$(pwd)../../..:/home/workspace" -it apigee/devrel-local \
  ./tools/pipeline-runner/pipeline-runner.sh

# run for single project
docker run -v "$(pwd)../../..:/home/workspace" -it apigee/devrel-local \
 ./tools/pipeline-runner/pipeline-runner.sh references/js-callout
