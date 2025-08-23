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


output "gke_cluster_name" {
  description = "The name of the GKE cluster."
  value       = google_container_cluster.gke.name
}

output "gke_cluster_endpoint" {
  description = "The IP address of the GKE cluster endpoint."
  value       = google_container_cluster.gke.endpoint
}

output "kubeconfig_path" {
  description = "Path to the generated kubeconfig file."
  value       = local_file.kubeconfig.filename
}

output "vpc_name" {
  description = "The name of the VPC network."
  value       = google_compute_network.vpc.name
}

output "subnet_name" {
  description = "The name of the subnet."
  value       = google_compute_subnetwork.subnet.name
}

output "apigee_organization_id" {
  description = "The ID of the Apigee organization."
  value       = module.apigee_hybrid.apigee_organization_id
}

output "apigee_environment_name" {
  description = "The name of the Apigee environment."
  value       = module.apigee_hybrid.apigee_environment_name
}

output "apigee_envgroup_id" {
  description = "The ID of the Apigee environment group."
  value       = module.apigee_hybrid.apigee_envgroup_id
}

output "apigee_non_prod_sa_email" {
  description = "Email of the Apigee Non-Prod service account."
  value       = module.apigee_hybrid.apigee_non_prod_sa_email
} 