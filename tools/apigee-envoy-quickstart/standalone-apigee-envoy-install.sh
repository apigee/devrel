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

echo "Installing apigee standalone envoy PoC setup"

if [ "$PLATFORM" == 'opdk' ] || [ "$PLATFORM" == 'edge' ]
then
    printf "\n\nInstall against opdk/edge platform, skipping service account creation"
else
    printf "\n\nstep 1 : service-accounts.sh\n" 
    ./scripts/service-accounts.sh
fi

printf "\n\nstep 2 : download-libraries.sh\n"
./scripts/download-libraries.sh

printf "\n\nstep 3 : setup-libraries.sh\n"
./scripts/setup-libraries.sh

printf "\n\nstep 4 : setup-apigee.sh\n"
./scripts/setup-apigee.sh

printf "\n\nstep 5 : setup-standalone-envoy.sh\n"
./scripts/setup-standalone-envoy.sh

printf "\n\nstep 6 : test-standalone-apigee-envoy-filter.sh\n"
./scripts/test-standalone-apigee-envoy-filter.sh
