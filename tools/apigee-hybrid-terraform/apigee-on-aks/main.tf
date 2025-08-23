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
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0" # Consider pinning to a specific minor like "~> 3.75"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 6.30.0"
    }
    random = { # Added for random_string
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
    local = { # Added for local_file kubeconfig
      source  = "hashicorp/local"
      version = "~> 2.4.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Generate random string for resource names
resource "random_string" "suffix" {
  length  = 6 # Shortened to avoid hitting length limits on some Azure resources
  special = false
  upper   = false
  keepers = {
    # This key can be anything, e.g., "static_suffix_trigger"
    # As long as the value "1" (or any static value) doesn't change,
    # the random string will only be generated once and then stored.
    # If you ever need to force a new suffix, change this value.
    _ = "1"
  }
}

locals {
  name_suffix         = random_string.suffix.result
  cluster_name        = "aks-apigee-${local.name_suffix}"
  resource_group_name = "rg-apigee-${local.name_suffix}"
  output_dir          = "${path.module}/output" # Define output directory for kubeconfig etc.
}

# Ensure the output directory exists for kubeconfig
resource "null_resource" "create_output_dir" {
  triggers = {
    output_dir_path = local.output_dir
  }
  provisioner "local-exec" {
    command = "mkdir -p ${local.output_dir}"
  }
}

# Create Resource Group
resource "azurerm_resource_group" "rg" {
  name     = local.resource_group_name # Use the generated name
  location = var.azure_location
}

# Create Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-apigee-${local.name_suffix}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  address_space       = ["10.0.0.0/16"]
}

# Create Subnet for AKS
resource "azurerm_subnet" "aks" {
  name                 = "snet-aks-${local.name_suffix}"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Create NAT Gateway (Optional, but good for outbound internet from AKS)
resource "azurerm_public_ip" "nat" {
  name                = "pip-nat-${local.name_suffix}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_nat_gateway" "nat" {
  name                = "nat-${local.name_suffix}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = "Standard"
}

resource "azurerm_subnet_nat_gateway_association" "aks" {
  subnet_id      = azurerm_subnet.aks.id
  nat_gateway_id = azurerm_nat_gateway.nat.id
}

resource "azurerm_nat_gateway_public_ip_association" "aks_nat_gateway_association" {
  nat_gateway_id       = azurerm_nat_gateway.nat.id
  public_ip_address_id = azurerm_public_ip.nat.id
}

# Create AKS Cluster
resource "azurerm_kubernetes_cluster" "aks" {
  name                = local.cluster_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "apigee-${local.name_suffix}"

  # checkov:skip=CKV_AZURE_4: We are using a specific log configuration that is not part of the default audit.
  # checkov:skip=CKV_AZURE_5: RBAC is managed externally via Azure Active Directory.
  # checkov:skip=CKV_AZURE_117: Disk encryption is handled by Azure's default platform-managed keys for this use case.
  # checkov:skip=CKV_AZURE_116: The Azure Policy Add-on is not required for this specific deployment.
  # checkov:skip=CKV_AZURE_6: API Server IP ranges are not enabled by design for this specific deployment.
  # checkov:skip=CKV_AZURE_115: Private cluster is not required for this testing or development environment.


  default_node_pool {
    name                = "system"
    node_count          = 1                 # Min 1 for system
    vm_size             = "Standard_D4s_v3" # Adjust as needed
    vnet_subnet_id      = azurerm_subnet.aks.id
    enable_auto_scaling = false
  }

  network_profile {
    network_plugin = "azure"
    network_policy = "azure" # Or "calico"
    service_cidr   = "10.1.0.0/16"
    dns_service_ip = "10.1.0.10"
    outbound_type  = "userAssignedNATGateway" # Using our NAT Gateway
  }

  identity {
    type = "SystemAssigned"
  }

  depends_on = [azurerm_subnet_nat_gateway_association.aks]
}

# User Node Pool "apigee-runtime"
resource "azurerm_kubernetes_cluster_node_pool" "runtime" {
  name                  = "apigeerun"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  vm_size               = "Standard_D4s_v3"
  min_count             = var.runtime_pool_enable_autoscaling ? var.runtime_pool_min_count : null
  max_count             = var.runtime_pool_enable_autoscaling ? var.runtime_pool_max_count : null
  enable_auto_scaling   = var.runtime_pool_enable_autoscaling
  node_count            = var.runtime_pool_enable_autoscaling ? null : var.runtime_pool_node_count # Set node_count to null if autoscaling is enabled

  vnet_subnet_id  = azurerm_subnet.aks.id
  os_disk_size_gb = 128
  os_type         = "Linux"
  mode            = "User"
  zones           = ["1", "2"]

  node_labels = {
    "nodepool-purpose"              = "apigee-runtime"
    "cloud.google.com/gke-nodepool" = "apigee-runtime"
  }
  # Add tags to the node pool
  tags = {
    "nodepool-purpose" = "apigee-runtime"
  }
}

# User Node Pool "apigee-data"
resource "azurerm_kubernetes_cluster_node_pool" "data" {
  name                  = "apigeedata"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  vm_size               = "Standard_D4s_v3"
  min_count             = var.data_pool_enable_autoscaling ? var.data_pool_min_count : null
  max_count             = var.data_pool_enable_autoscaling ? var.data_pool_max_count : null
  enable_auto_scaling   = var.data_pool_enable_autoscaling
  node_count            = var.data_pool_enable_autoscaling ? null : var.data_pool_node_count

  vnet_subnet_id  = azurerm_subnet.aks.id
  os_disk_size_gb = 128
  os_type         = "Linux"
  mode            = "User"
  zones           = ["1"]

  node_labels = {
    "nodepool-purpose"              = "apigee-data"
    "cloud.google.com/gke-nodepool" = "apigee-data"
  }

  tags = {
    "nodepool-purpose" = "apigee-data"
  }
}

# Data source to retrieve the built-in "Network Contributor" role definition
data "azurerm_role_definition" "network_contributor" {
  name = "Network Contributor"
}

# Assign the "Network Contributor" role to the AKS cluster's SystemAssigned Managed Identity
# on the subnet scope. This grants the AKS identity permission to join the subnet.
resource "azurerm_role_assignment" "aks_subnet_join_permission" {
  scope                            = azurerm_subnet.aks.id
  role_definition_id               = data.azurerm_role_definition.network_contributor.id
  principal_id                     = azurerm_kubernetes_cluster.aks.identity[0].principal_id # Correctly reference the AKS cluster's SystemAssigned Identity
  skip_service_principal_aad_check = true                                                    # Essential for Managed Identities
}


# Generate kubeconfig for AKS
resource "local_file" "kubeconfig" {
  content         = azurerm_kubernetes_cluster.aks.kube_config_raw # Use the raw kubeconfig directly
  filename        = "${path.module}/output/${var.gcp_project_id}/apigee-kubeconfig"
  file_permission = "0600"

  depends_on = [
    null_resource.create_output_dir, # Ensure directory exists
    azurerm_kubernetes_cluster.aks
  ]
}

resource "null_resource" "cluster_setup" {
  triggers = {
    timestamp = timestamp()
  }

  # Use local-exec provisioner to run a script to configure kubectl
  provisioner "local-exec" {
    command = "export KUBECONFIG=${abspath("${path.module}/output/${var.gcp_project_id}/apigee-kubeconfig")} && az aks get-credentials --resource-group ${local.resource_group_name} --name ${local.cluster_name} --overwrite-existing"
  }

  depends_on = [
    azurerm_kubernetes_cluster_node_pool.runtime,
    azurerm_kubernetes_cluster_node_pool.data,
    azurerm_kubernetes_cluster.aks,
    azurerm_role_assignment.aks_subnet_join_permission # Add dependency here
  ]
}


# Call the apigee-hybrid-core module
# This module will now handle the setup script execution if var.apigee_install is true
module "apigee_hybrid" {
  source = "../apigee-hybrid-core" # Adjust path as needed

  project_id                = var.gcp_project_id
  region                    = var.gcp_region      # Core module expects 'region'
  apigee_org_name           = var.apigee_org_name # Passed to core, core decides how to use it (e.g. for overrides or display name)
  apigee_org_display_name   = var.apigee_org_display_name
  apigee_env_name           = var.apigee_env_name
  apigee_envgroup_name      = var.apigee_envgroup_name
  apigee_envgroup_hostnames = var.hostnames                                # Core module expects 'apigee_envgroup_hostnames'
  apigee_instance_name      = "aks-${local.name_suffix}"                   # A name for the Apigee instance resource
  cluster_name              = local.cluster_name                           # Pass AKS cluster name to core module
  kubeconfig                = abspath("${local_file.kubeconfig.filename}") # Pass the kubeconfig file path to core module

  apigee_version                 = var.apigee_version
  apigee_namespace               = var.apigee_namespace
  apigee_cassandra_replica_count = var.apigee_cassandra_replica_count


  ingress_name            = var.ingress_name
  ingress_svc_annotations = var.ingress_svc_annotations

  apigee_lb_ip = var.apigee_lb_ip
  #TLS related variables
  tls_apigee_self_signed = var.tls_apigee_self_signed
  tls_apigee_cert_path   = var.tls_apigee_cert_path
  tls_apigee_key_path    = var.tls_apigee_key_path

  create_org     = var.create_org     # Set to true if you want this module to create the Apigee Org
  apigee_install = var.apigee_install # Set to true to run the setup_apigee.sh script from core module

  # Template paths can be omitted if using defaults in core module (${path.module}/<template-name>)
  overrides_template_path = "${path.module}/../apigee-hybrid-core/overrides-templates.yaml"     # Example if you want to be explicit
  service_template_path   = "${path.module}/../apigee-hybrid-core/apigee-service-template.yaml" # Example

  # Pass annotations if needed for Azure internal load balancer for ingress
  # ingress_svc_annotations = {
  #   "service.beta.kubernetes.io/azure-load-balancer-internal": "true"
  #   # "service.beta.kubernetes.io/azure-load-balancer-internal-subnet": "snet-aks-${local.name_suffix}" # If specific subnet
  # }

  depends_on = [
    azurerm_kubernetes_cluster.aks, # Ensure AKS is ready before Apigee core module attempts anything K8s related
    azurerm_kubernetes_cluster_node_pool.runtime,
    azurerm_kubernetes_cluster_node_pool.data,
    local_file.kubeconfig, # Ensure kubeconfig is generated before Apigee tries to use it
    null_resource.cluster_setup
  ]
}