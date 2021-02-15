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

QUICKSTART_ROOT="$( cd "$(dirname "$0")" || exit >/dev/null 2>&1 ; pwd -P )"
export QUICKSTART_ROOT

ENV_NAME=${ENV_NAME:="test1"}
ENV_GROUP_NAME=${ENV_GROUP_NAME:="test"}

source "$QUICKSTART_ROOT/steps.sh"

# enables all reqired GCP APIs
enable_all_apis

# configure installation
set_config_params

# create an Apigee organization with the same name as the GCP project
create_apigee_org

# create an Apigee environment
create_apigee_env $ENV_NAME

# create an Apigee environment group
create_apigee_envgroup $ENV_GROUP_NAME

# attach an Apigee environment to an environment group
add_env_to_envgroup $ENV_NAME $ENV_GROUP_NAME

# configure an ingress IP and DNS entry for the env group hostname
configure_network $ENV_GROUP_NAME

# create a minimal GKE cluster with a single node pool
create_gke_cluster

# install Anthos service mesh and certmanager
install_asm_and_certmanager

# download the Apigeectl utility
download_apigee_ctl

# configure the Apigee override parameters
prepare_resources

# create self-signed certificate for env group hostname
create_self_signed_cert $ENV_GROUP_NAME

# create all required service accounts and download their keys
create_sa

# install the Apigee runtime
install_runtime $ENV_NAME $ENV_GROUP_NAME

# deploy an example proxy to the given environment
deploy_example_proxy $ENV_NAME $ENV_GROUP_NAME
