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


# AWS Configuration
eks_region     = "us-west-1"          # AWS region for EKS cluster


# Apigee Configuration
project_id               = "apigee-eks-example2"  # Replace with your actual GCP project ID
region                   = "us-west1" #GCP Region
apigee_org_name          = "apigee-eks-example2"  # Must be unique across all Apigee organizations
apigee_env_name          = "dev"                 # Environment name (dev, test, prod, etc.)
apigee_envgroup_name     = "dev-group"           # Environment group name
cluster_name             = "apigee-eks"          # EKS cluster name
apigee_namespace         = "apigee"              # Kubernetes namespace for Apigee components
apigee_version           = "1.15.0"     # Apigee Hybrid version
apigee_org_display_name  = "My Company Apigee Organization"
apigee_env_display_name  = "Development Environment"
apigee_instance_name     = "apigee-instance"
apigee_cassandra_replica_count = 1    # Number of Cassandra replicas (recommended: 3 for production)


# Hostnames for Apigee Environment Group
# These are the domains that will be used to access your APIs
hostnames = [
  "api.mycompany.com",           # Production API endpoint
  "api-dev.mycompany.com"        # Development API endpoint
]

#TLS related variable
tls_apigee_self_signed = true
tls_apigee_cert_path = "path/to/your/tls.crt"
tls_apigee_key_path = "path/to/your/tls.key"

#Load Balancer IP
#apigee_lb_ip="35.188.116.91"


create_org=true
apigee_install=true

# Ingress Configuration
ingress_name = "apigee-ingress"
ingress_svc_annotations = {
  # AWS-specific annotations for Network Load Balancer
  #"service.beta.kubernetes.io/aws-load-balancer-type" = "nlb"
  #"service.beta.kubernetes.io/aws-load-balancer-internal" = "true"
  #"service.beta.kubernetes.io/aws-load-balancer-scheme" = "internet-facing"
  #"service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled" = "true"
  
  # Optional: Add these if you need SSL termination
  # "service.beta.kubernetes.io/aws-load-balancer-ssl-cert" = "arn:aws:acm:region:account:certificate/certificate-id"
  # "service.beta.kubernetes.io/aws-load-balancer-backend-protocol" = "ssl"
  # "service.beta.kubernetes.io/aws-load-balancer-ssl-ports" = "443"
}

# Optional: Paths to template files if you want to use custom templates
# Uncomment and set these if you have custom templates
# overrides_template_path = "../apigee-hybrid-core/overrides-templates.yaml"
# service_template_path   = "../apigee-hybrid-core/apigee-service-template.yaml"

# Billing Configuration
billing_type = "EVALUATION"  # Options: "EVALUATION" or "PAID"
# Note: For production use, set this to "PAID"

