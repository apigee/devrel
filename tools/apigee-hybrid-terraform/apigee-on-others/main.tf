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


terraform {
  required_version = ">= 1.0.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.30.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.0.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "kubernetes" {
  # Configuration will be automatically loaded from KUBECONFIG
  # or from the default location (~/.kube/config)
}

provider "helm" {
  # Configuration will be automatically loaded from KUBECONFIG
  # or from the default location (~/.kube/config)
}

# Use the apigee-hybrid-core module
module "apigee_hybrid" {
  source = "../apigee-hybrid-core"

  project_id                  = var.project_id
  region                      = var.region
  apigee_org_name             = var.apigee_org_name
  apigee_env_name             = var.apigee_env_name
  apigee_envgroup_name        = var.apigee_envgroup_name
  apigee_namespace            = var.apigee_namespace
  apigee_version              = var.apigee_version
  cluster_name                = var.cluster_name
  apigee_org_display_name     = var.apigee_org_display_name
  apigee_env_display_name     = var.apigee_env_display_name
  apigee_instance_name        = var.apigee_instance_name
  apigee_envgroup_hostnames   = var.hostnames
  apigee_cassandra_replica_count = var.apigee_cassandra_replica_count
  ingress_name                = var.ingress_name
  ingress_svc_annotations     = var.ingress_svc_annotations
  overrides_template_path     = "${path.module}/../apigee-hybrid-core/overrides-templates.yaml" # Example if you want to be explicit
  service_template_path       = "${path.module}/../apigee-hybrid-core/apigee-service-template.yaml" # Example

  apigee_lb_ip                = var.apigee_lb_ip
  #TLS related variables
  tls_apigee_self_signed      = var.tls_apigee_self_signed
  tls_apigee_cert_path        = var.tls_apigee_cert_path
  tls_apigee_key_path         = var.tls_apigee_key_path

  create_org                  = var.create_org
  apigee_install              = var.apigee_install
  billing_type                = var.billing_type


}