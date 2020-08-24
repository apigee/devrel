#!/bin/bash

source ./steps.sh

set_config_params

check_existing_apigee_org

enable_all_apis

create_apigee_org

create_apigee_env "test"

configure_network

create_gke_cluster

download_apigee_ctl

prepare_resources

create_sa

install_runtime