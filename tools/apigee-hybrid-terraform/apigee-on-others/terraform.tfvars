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


# GCP Configuration
project_id = "apigee-gke-example3"  # Replace with your actual GCP project ID
region     = "us-central1"        # Default region, change if needed

# Apigee Configuration
apigee_org_name          = "apigee-gke-example3"           # Must be unique across all Apigee organizations
apigee_env_name          = "dev"              # Environment name (dev, test, prod, etc.)
apigee_envgroup_name     = "dev-group"        # Environment group name
cluster_name             = "apigee"           # Kubernetes cluster name
apigee_namespace         = "apigee"           # Kubernetes namespace for Apigee components
apigee_version           = "1.15.0"  # Apigee Hybrid version
apigee_org_display_name  = "My Company Apigee Organization"
apigee_env_display_name  = "Development Environment"
apigee_instance_name     = "apigee-instance"
apigee_cassandra_replica_count = 3            # Number of Cassandra replicas (recommended: 3 for production)

# Hostnames for Apigee Environment Group
# These are the domains that will be used to access your APIs
hostnames = [
  "api.mycompany.com",           # Production API endpoint
  "api-dev.mycompany.com"        # Development API endpoint
]

#TLS related variable
tls_apigee_self_signed = true
#tls_apigee_cert_path = "tls.crt"
#tls_apigee_key_path = "tls.key"

#Load Balancer IP
#apigee_lb_ip="35.188.116.91"

create_org=false
apigee_install=true

# Ingress Configuration
ingress_name = "apigee-ingress"
ingress_svc_annotations = {
  # Uncomment and modify these based on your cloud provider
  # For AWS:
  # "service.beta.kubernetes.io/aws-load-balancer-type" = "nlb"
  # "service.beta.kubernetes.io/aws-load-balancer-internal" = "true"
  
  # For GCP:
  #"networking.gke.io/load-balancer-type": "Internal"

  # For Azure:
  # "service.beta.kubernetes.io/azure-load-balancer-internal" = "true"
  # "service.beta.kubernetes.io/azure-load-balancer-internal-subnet" = "your-subnet-name"
}

# Optional: Paths to template files if you want to use custom templates
# Uncomment and set these if you have custom templates
# overrides_template_path = "../apigee-hybrid-core/overrides-templates.yaml"
# service_template_path   = "../apigee-hybrid-core/apigee-service-template.yaml"

# Billing Configuration
billing_type = "EVALUATION"  # Options: "EVALUATION" or "PAID"
# Note: For production use, set this to "PAID" 
