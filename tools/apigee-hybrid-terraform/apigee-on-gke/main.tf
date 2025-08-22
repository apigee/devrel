terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.30.0" # Ensure compatibility with the Google provider
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Enable required APIs
resource "google_project_service" "required_apis" {
  for_each = toset([
    "compute.googleapis.com",
    "container.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "apigee.googleapis.com",
    "apigeeconnect.googleapis.com",
    "cloudkms.googleapis.com",
    "servicenetworking.googleapis.com"
  ])
  
  project = var.project_id
  service = each.key

  disable_dependent_services = false
  disable_on_destroy        = false
}

# Generate a random suffix for resource names
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
  # Add this keepers block
  keepers = {
    # This key can be anything, e.g., "static_suffix_trigger"
    # As long as the value "1" (or any static value) doesn't change,
    # the random string will only be generated once and then stored.
    # If you ever need to force a new suffix, change this value.
    _ = "1"
  }
}

locals {
  name_suffix = random_string.suffix.result
}

# Create VPC Network
resource "google_compute_network" "vpc" {
  name                    = "vpc-apigee-${local.name_suffix}"
  auto_create_subnetworks = false

  depends_on = [
    google_project_service.required_apis
  ]
}

# Create Subnet
resource "google_compute_subnetwork" "subnet" {
  name          = "subnet-apigee-${local.name_suffix}"
  ip_cidr_range = "10.0.0.0/16"
  region        = var.region
  network       = google_compute_network.vpc.id

  secondary_ip_range {
    range_name    = "pod-range"
    ip_cidr_range = "10.1.0.0/16"
  }

  secondary_ip_range {
    range_name    = "service-range"
    ip_cidr_range = "10.2.0.0/16"
  }
}

# Create Cloud Router
resource "google_compute_router" "router" {
  name    = "router-apigee-${local.name_suffix}"
  region  = var.region
  network = google_compute_network.vpc.id
}

# Create Cloud NAT
resource "google_compute_router_nat" "nat" {
  name                               = "nat-apigee-${local.name_suffix}"
  router                            = google_compute_router.router.name
  region                            = google_compute_router.router.region
  nat_ip_allocate_option            = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# Create GKE Cluster
resource "google_container_cluster" "gke" {
  name     = "gke-apigee-${local.name_suffix}"
  location = var.region
  deletion_protection = false

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = google_compute_network.vpc.id
  subnetwork = google_compute_subnetwork.subnet.id

  ip_allocation_policy {
    cluster_secondary_range_name  = "pod-range"
    services_secondary_range_name = "service-range"
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block = "172.16.0.0/28"
  }

  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "0.0.0.0/0"  # Consider restricting this in production
      display_name = "All"
    }
  }

  # Add network tags for NAT
  network_policy {
    enabled = true
  }

  # Add network tags for NAT
  node_config {
    tags = ["nat-route"]
  }
  lifecycle {
    ignore_changes = [
      initial_node_count,
      ]
  }
}


# Create Node Pool for Runtime
resource "google_container_node_pool" "runtime" {
  name         = "apigee-runtime"
  location     = var.region
  cluster      = google_container_cluster.gke.name
  node_count   = 1

  node_config {
    machine_type = "e2-standard-4"
    disk_size_gb = 100
    disk_type    = "pd-standard"

    labels = {
      "apigee-runtime" = "true"
      "temp-update-trigger" = "true" # Add this line
    }
    tags = ["apigee-runtime", "nat-route"]
    
  }
  management {
    auto_repair  = true
    auto_upgrade = true
  }
  lifecycle {
      ignore_changes = all
  }
}

# Create Node Pool for Data
resource "google_container_node_pool" "data" {
  name         = "apigee-data"
  location     = var.region
  cluster      = google_container_cluster.gke.name
  node_count   = 1

  node_config {
    machine_type = "e2-standard-4"
    disk_size_gb = 100
    disk_type    = "pd-standard"

    labels = {
      "apigee-data" = "true"
      "temp-update-trigger" = "true" # Add this line
    }
    tags = ["apigee-data", "nat-route"]
    
  }
  management {
    auto_repair  = true
    auto_upgrade = true
  }
  lifecycle {
      ignore_changes = all
  }

}

# Generate kubeconfig
resource "local_file" "kubeconfig" {
  content  = <<-KUBECONFIG
  apiVersion: v1
  kind: Config
  current-context: ${google_container_cluster.gke.name}
  contexts:
  - context:
      cluster: ${google_container_cluster.gke.name}
      user: ${google_container_cluster.gke.name}
    name: ${google_container_cluster.gke.name}
  clusters:
  - cluster:
      certificate-authority-data: ${google_container_cluster.gke.master_auth[0].cluster_ca_certificate}
      server: https://${google_container_cluster.gke.endpoint}
    name: ${google_container_cluster.gke.name}
  users:
  - name: ${google_container_cluster.gke.name}
    user:
      exec:
        apiVersion: client.authentication.k8s.io/v1beta1
        command: gcloud
        args:
        - container
        - clusters
        - get-credentials
        - ${google_container_cluster.gke.name}
        - --region=${var.region}
        - --project=${var.project_id}
  KUBECONFIG
    filename = "${path.module}/output/${var.project_id}/apigee-kubeconfig"
    file_permission = "0600"

  depends_on = [
    null_resource.create_output_dir,
    google_container_node_pool.runtime,     # Ensure node pools are up before module might use kubeconfig
    google_container_node_pool.data
  ]
}


resource "null_resource" "cluster_setup" {
  # Use local-exec provisioner to run a script to configure kubectl
  triggers = {
    timestamp = timestamp()
  }

  provisioner "local-exec" {
    command = "export KUBECONFIG=${abspath("${path.module}/output/${var.project_id}/apigee-kubeconfig")} && gcloud container clusters get-credentials ${google_container_cluster.gke.name} --region ${var.region} --project ${var.project_id}"
  }
  depends_on = [
    local_file.kubeconfig,
    google_container_cluster.gke,
  ]
}

# Create output directory if it doesn't exist
resource "null_resource" "create_output_dir" {
  provisioner "local-exec" {
    command = "mkdir -p ${path.module}/output/${var.project_id}"
  }
}

# Use the apigee-hybrid-core module
module "apigee_hybrid" {
  source = "../apigee-hybrid-core"

  project_id                = var.project_id
  region                    = var.region
  apigee_org_name          = var.apigee_org_name
  apigee_env_name          = var.apigee_env_name
  apigee_envgroup_name     = var.apigee_envgroup_name
  apigee_namespace         = var.apigee_namespace
  apigee_version           = var.apigee_version
  cluster_name             = google_container_cluster.gke.name
  kubeconfig               = abspath("${path.module}/output/${var.project_id}/apigee-kubeconfig")
  
  apigee_org_display_name  = var.apigee_org_display_name
  apigee_env_display_name  = var.apigee_env_display_name
  apigee_instance_name     = var.apigee_instance_name
  apigee_envgroup_hostnames = var.hostnames
  apigee_cassandra_replica_count = var.apigee_cassandra_replica_count
  ingress_name             = var.ingress_name
  ingress_svc_annotations  = var.ingress_svc_annotations
  overrides_template_path = "${path.module}/../apigee-hybrid-core/overrides-templates.yaml" # Example if you want to be explicit
  service_template_path   = "${path.module}/../apigee-hybrid-core/apigee-service-template.yaml" # Example

  apigee_lb_ip                = var.apigee_lb_ip
  #TLS related variables
  tls_apigee_self_signed      = var.tls_apigee_self_signed
  tls_apigee_cert_path        = var.tls_apigee_cert_path
  tls_apigee_key_path         = var.tls_apigee_key_path

  create_org                  = var.create_org
  apigee_install              = var.apigee_install
  billing_type                = var.billing_type

  depends_on = [
    google_container_cluster.gke,
    google_container_node_pool.runtime,
    google_container_node_pool.data,
    local_file.kubeconfig,
    null_resource.cluster_setup,
  ]
} 
