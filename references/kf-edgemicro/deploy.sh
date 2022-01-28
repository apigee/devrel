#!/bin/bash

# Copyright 2022 Google LLC
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


set -euxo pipefail

source ./deploy_helper.sh

validate_edgemicro_vars

# target the 'kf-apigee' namespace for apps
app_space="kf-apigee"
kf target -s ${app_space}

for i in {1..3}
do
  # push the httpbin application and set the route to the internal domain
  app_name="httpbin-${i}"
  kf push ${app_name} --docker-image kennethreitz/httpbin --route "${app_name}.apps.internal"

  emg-util publish-proxy \
    -n "edgemicro_${app_name}" \
    -b "/${app_name}" \
    -t "http://${app_name}.${app_space}" \
    -o "${EDGEMICRO_ORG}" \
    -e "${EDGEMICRO_ENV}" \
    -u "${APIGEE_USERNAME}" \
    -p "${APIGEE_PASSWORD}"

  emg-util update-product \
    -n "edgemicro_product" \
    -a "edgemicro_${app_name}" \
    -o "${EDGEMICRO_ORG}" \
    -e "${EDGEMICRO_ENV}" \
    -u "${APIGEE_USERNAME}" \
    -p "${APIGEE_PASSWORD}"
done

# target the 'emg' namespace for the edge microgateway
emg_space=emg
kf target -s ${emg_space}

export EDGEMICRO_CONFIG=$(envsubst < ./emg-kf/emg-config-template.yml | base64_encode)
kf push -f <(envsubst < ./emg-kf/emg-manifest-template.yml)

