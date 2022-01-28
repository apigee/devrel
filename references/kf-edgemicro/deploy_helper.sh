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


function validate_edgemicro_vars() {
  if [ -z "${EDGEMICRO_ORG}" ] ; then
    echo "Error: \${EDGEMICRO_ORG} is not defined" && exit 1
  fi

  if [ -z "${EDGEMICRO_ENV}" ] ; then
    echo "Error: \${EDGEMICRO_ENV} is not defined" && exit 1
  fi

  if [ -z "${EDGEMICRO_KEY}" ] ; then
    echo "Error: \${EDGEMICRO_KEY} is not defined" && exit 1
  fi

  if [ -z "${EDGEMICRO_SECRET}" ] ; then
    echo "Error: \${EDGEMICRO_KEY} is not defined" && exit 1
  fi

  if [ -z "${EDGEMICRO_DOCKER_IMAGE}" ] ; then
    echo "Error: \${EDGEMICRO_DOCKER_IMAGE} is not defined" && exit 1
  fi

  if [ -z "${APIGEE_USERNAME}" ] ; then
    echo "Error: \${APIGEE_USERNAME} is not defined" && exit 1
  fi

  if [ -z "${APIGEE_PASSWORD}" ] ; then
    echo "Error: \${APIGEE_PASSWORD} is not defined" && exit 1
  fi
}

function base64_encode() {
  OSNAME=$(uname -s)

  if [ "${OSNAME}" == "Darwin" ] ; then
    base64 "$@"
  elif [ "${OSNAME}" == "Linux" ] ; then
    base64 -w0 "$@"
  fi
}

