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


variable "azure_location" {
  description = "The Azure region to deploy resources"
  type        = string
  default     = "eastus"
}

variable "gcp_project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "gcp_region" {
  description = "The GCP region for Apigee control plane resources"
  type        = string
  default     = "us-central1"
}

variable "apigee_org_name" {
  description = "The name of the Apigee organization (typically the GCP Project ID)."
  type        = string
  # This will be used as the org_name in overrides.yaml if provided,
  # otherwise the core module defaults to using var.gcp_project_id.
}

variable "apigee_env_name" {
  description = "The name of the Apigee environment"
  type        = string
  default     = "dev"
}

variable "apigee_envgroup_name" {
  description = "The name of the Apigee environment group"
  type        = string
  default     = "dev-group" # Changed default to avoid conflict with env_name if both are 'dev'
}

variable "apigee_namespace" {
  description = "The Kubernetes namespace for Apigee"
  type        = string
  default     = "apigee"
}

variable "apigee_version" {
  description = "The version of Apigee Hybrid to install"
  type        = string
  # e.g., default = "1.14.2-hotfix.1" - It's better to define this in one place, perhaps here.
}

variable "hostnames" {
  description = "The list of hostnames for the Apigee environment group"
  type        = list(string)
  # e.g., default = ["myapi.example.com"]
}

# System Node Pool Variables
variable "system_pool_node_count" {
  description = "The number of nodes for the system node pool."
  type        = number
  default     = 1
}


variable "runtime_pool_enable_autoscaling" {
  description = "Whether to enable autoscaling for the Apigee Runtime node pool."
  type        = bool
  default     = false
}

variable "runtime_pool_node_count" {
  description = "Node count in case autoscaling is false."
  type        = number
  default     = 2
}

# Apigee Runtime Node Pool Variables
variable "runtime_pool_min_count" {
  description = "Minimum number of nodes for the Apigee Runtime node pool."
  type        = number
  default     = 2
}

variable "runtime_pool_max_count" {
  description = "Maximum number of nodes for the Apigee Runtime node pool."
  type        = number
  default     = 2
}

variable "data_pool_enable_autoscaling" {
  description = "Whether to enable autoscaling for the Apigee Data node pool."
  type        = bool
  default     = false
}

variable "data_pool_node_count" {
  description = "Number of nodes for the Apigee Data node pool in case autoscale is false"
  type        = number
  default     = 1
}

# Apigee Data Node Pool Variables
variable "data_pool_min_count" {
  description = "Minimum number of nodes for the Apigee Data node pool."
  type        = number
  default     = 1
}

variable "data_pool_max_count" {
  description = "Maximum number of nodes for the Apigee Data node pool."
  type        = number
  default     = 1
}

#Add variable for svcAnnotations
variable "ingress_svc_annotations" {
  description = "Service Annotations for Apigee Services"
  type        = map(string)
  default     = {}
}

variable "ingress_name" {
  description = "The name of the ingress resource for Apigee"
  type        = string
  default     = "apigee-ingress"
}

variable "apigee_org_display_name" {
  description = "The display name for the Apigee organization"
  type        = string
  default     = ""
}

variable "apigee_cassandra_replica_count" {
  description = "Number of Cassandra replicas for Apigee"
  type        = number
  default     = 3
}

variable "create_org" {
  description = "Whether to create a new Apigee organization"
  type        = bool
  default     = true
}

variable "apigee_install" {
  description = "Whether to run the Apigee installation script"
  type        = bool
  default     = true
}

variable "billing_type" {
  description = "The billing type for the Apigee organization (EVALUATION or PAID)"
  type        = string
  default     = "EVALUATION"
  validation {
    condition     = contains(["EVALUATION", "PAID"], var.billing_type)
    error_message = "Billing type must be either EVALUATION or PAID."
  }
}

variable "tls_apigee_self_signed" {
  description = "Whether to use self-signed certificates for Apigee TLS. If true, self-signed certs will be generated. If false, provide tls_apigee_cert and tls_apigee_key."
  type        = bool
  default     = true
}

variable "tls_apigee_cert_path" {
  description = "The TLS certificate for Apigee. Required if tls_apigee_self_signed is false."
  type        = string
  default     = ""
}

variable "tls_apigee_key_path" {
  description = "The TLS private key for Apigee. Required if tls_apigee_self_signed is false."
  type        = string
  default     = ""
  sensitive   = true
}

variable "apigee_lb_ip" {
  type        = string
  description = "IP address for the Apigee Load Balancer."
  default     = ""
}