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

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region for resources"
  type        = string
  default     = "us-central1"
}

variable "apigee_org_name" {
  description = "The name of the Apigee organization"
  type        = string
}

variable "apigee_env_name" {
  description = "The name of the Apigee environment"
  type        = string
  default     = "dev"
}

variable "apigee_envgroup_name" {
  description = "The name of the Apigee environment group"
  type        = string
  default     = "dev"
}

variable "apigee_namespace" {
  description = "The Kubernetes namespace for Apigee"
  type        = string
  default     = "apigee"
}

variable "apigee_version" {
  description = "The version of Apigee to install"
  type        = string
  default     = "1.14.2-hotfix.1"
}

variable "hostnames" {
  description = "List of hostnames for the Apigee environment group"
  type        = list(string)
}

variable "create_org" {
  description = "Whether to create a new Apigee organization"
  type        = bool
  default     = true
}

variable "apigee_org_display_name" {
  description = "Display name for the Apigee organization"
  type        = string
  default     = ""
}

variable "apigee_env_display_name" {
  description = "Display name for the Apigee environment"
  type        = string
  default     = ""
}

variable "apigee_instance_name" {
  description = "Name of the Apigee instance"
  type        = string
  default     = "apigee-instance"
}

variable "apigee_cassandra_replica_count" {
  description = "Number of Cassandra replicas"
  type        = number
  default     = 3
}

variable "ingress_name" {
  description = "Name of the ingress"
  type        = string
  default     = "apigee-ingress"
}

variable "ingress_svc_annotations" {
  description = "Annotations for the ingress service"
  type        = map(string)
  default     = {}
}

variable "overrides_template_path" {
  description = "Path to the overrides template file"
  type        = string
  default     = ""
}

variable "service_template_path" {
  description = "Path to the service template file"
  type        = string
  default     = ""
}

variable "apigee_install" {
  description = "Whether to install Apigee components"
  type        = bool
  default     = true
}

variable "billing_type" {
  description = "The billing type for the Apigee organization"
  type        = string
  default     = "EVALUATION"
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