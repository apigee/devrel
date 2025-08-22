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


output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ids attached to the cluster control plane"
  value       = module.eks.cluster_security_group_id
}

output "eks_region" {
  description = "AWS region"
  value       = var.eks_region
}

output "cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = module.eks.cluster_name
}

output "eks_kubeconfig_path" {
  description = "Path to the generated kubeconfig file."
  value       = local_file.kubeconfig.filename
}

output "apigee_hybrid_non_prod_sa_email" {
  description = "Email of the Apigee Non-Prod service account from the core module."
  value       = module.apigee_hybrid.apigee_non_prod_sa_email
}

output "apigee_hybrid_non_prod_sa_key_path" {
  description = "Path to the saved Apigee Non-Prod service account key file from the core module."
  value       = module.apigee_hybrid.apigee_non_prod_sa_key_path
}

output "apigee_hybrid_overrides_yaml_path" {
  description = "Path to the generated Apigee Hybrid overrides.yaml file from the core module."
  value       = module.apigee_hybrid.apigee_overrides_yaml_path
}

output "apigee_hybrid_service_yaml_path" {
  description = "Path to the generated Apigee Hybrid apigee-service.yaml file from the core module."
  value       = module.apigee_hybrid.apigee_service_yaml_path
}

output "apigee_hybrid_envgroup_private_key_file_path" {
  description = "Path to the self-signed private key file for the Apigee envgroup from the core module."
  value       = module.apigee_hybrid.apigee_envgroup_private_key_file_path
}

output "apigee_hybrid_envgroup_cert_file_path" {
  description = "Path to the self-signed certificate file for the Apigee envgroup from the core module."
  value       = module.apigee_hybrid.apigee_envgroup_cert_file_path
}

output "apigee_hybrid_setup_script_executed_trigger" {
  description = "Indicates if the Apigee setup script was triggered from the core module."
  value       = module.apigee_hybrid.apigee_setup_script_executed_trigger
}

output "apigee_hybrid_organization_id" {
  description = "The ID of the Apigee organization from the core module."
  value       = module.apigee_hybrid.apigee_organization_id
}

output "apigee_hybrid_environment_name" {
  description = "The name of the Apigee environment from the core module."
  value       = module.apigee_hybrid.apigee_environment_name
}

output "apigee_hybrid_envgroup_id" {
  description = "The ID of the Apigee environment group from the core module."
  value       = module.apigee_hybrid.apigee_envgroup_id
}
