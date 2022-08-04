#!/bin/bash

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

if [[ -z $APIGEE_ORG ]]; then
    echo "Environment variable APIGEE_ORG is not set, please checkout README.md"
    exit 1
fi

if [[ -z $APIGEE_ENV ]]; then
    echo "Environment variable APIGEE_ENV is not set, please checkout README.md"
    exit 1
fi

if [ "$PLATFORM" == 'opdk' ] && [[ -z $MGMT_HOST ]]; then
    echo "Environment variable OPDK MGMT_HOST is not set, please checkout README.md"
    exit 1
fi

if [[ -z $APIGEE_USER ]]; then
    echo "Environment variable OPDK user credential is not set, please checkout README.md"
    exit 1
fi

if [[ -z $APIGEE_PASS ]]; then
    echo "Environment variable OPDK password credential is not set, please checkout README.md"
    exit 1
fi

echo "Validation standalone params successful.."
