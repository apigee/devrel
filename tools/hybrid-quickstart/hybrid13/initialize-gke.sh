#!/bin/bash

source ./steps.sh

set_config_params

enable_all_apis

create_apigee_org

create_apigee_env "test"

configure_network

create_gke_cluster

install_asm_and_certmanager

download_apigee_ctl

prepare_resources

create_sa

install_runtime

deploy_example_proxy