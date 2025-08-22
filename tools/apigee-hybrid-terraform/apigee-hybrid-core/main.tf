# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.30.0" # Consider pinning to a specific minor like "~> 4.80"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

# Generate random string for resource names
resource "random_string" "suffix" {
  length  = 6 # Shortened to avoid hitting length limits on some Azure resources
  special = false
  upper   = false
}

locals {
  random_suffix = substr(random_string.suffix.result, 0, 6)
  apigee_org_constructed_id = "organizations/${var.project_id}" # Apigee Org ID is the Project ID
  service_account_id_short  = "${var.apigee_service_account_name}"  #"apigee-non-prod-${local.random_suffix}" # Or make this configurable
  service_account_email     = "${local.service_account_id_short}@${var.project_id}.iam.gserviceaccount.com"

  effective_org_id = var.create_org ? (
    google_apigee_organization.apigee_org[0].id
  ) : local.apigee_org_constructed_id

  effective_env_name           = var.apigee_env_name
  effective_instance_name      = var.apigee_instance_name
  effective_envgroup_hostnames = var.apigee_envgroup_hostnames
  effective_envgroup_name      = var.apigee_envgroup_name

  effective_envgroup_id = var.create_org ? (
    google_apigee_envgroup.hybrid_envgroup[0].id
  ) : (local.effective_org_id != null ? "${local.effective_org_id}/envgroups/${var.apigee_envgroup_name}" : null)

  apigee_non_prod_sa_roles = [
    "roles/storage.objectAdmin",
    "roles/logging.logWriter",
    "roles/apigeeconnect.Agent",
    "roles/monitoring.metricWriter",
    "roles/apigee.synchronizerManager",
    "roles/apigee.analyticsAgent",
    "roles/apigee.runtimeAgent",
  ]

  primary_hostname_for_cert = length(var.apigee_envgroup_hostnames) > 0 ? var.apigee_envgroup_hostnames[0] : "default-apigee-host.example.com"
  cert_filename_prefix      = replace(local.primary_hostname_for_cert, ".", "-")

  output_dir = "output/${var.project_id}" # Centralize output directory path

  sa_key_filename_for_overrides       = basename(local_file.apigee_non_prod_sa_key_file.filename)
  cert_file_path_for_overrides        = basename(local_file.apigee_envgroup_cert_file.filename)
  private_key_file_path_for_overrides = basename(local_file.apigee_envgroup_private_key_file.filename)

  ingress_svc_annotations_yaml = length(var.ingress_svc_annotations) > 0 ? yamlencode(var.ingress_svc_annotations) : ""

  # Use module path for templates if specific paths aren't provided
  final_overrides_template_path = var.overrides_template_path != "" ? var.overrides_template_path : "${path.module}/overrides-templates.yaml"
  final_service_template_path   = var.service_template_path != "" ? var.service_template_path : "${path.module}/apigee-service-template.yaml"

  # Determine the org name for overrides.yaml. Default to project_id if var.apigee_org_name is not set.
  # Apigee Hybrid org ID is typically the GCP project ID.
  org_name_for_overrides = var.apigee_org_name != "" ? var.apigee_org_name : var.project_id
}

# ------------------------------------------------------------------------------
# Enable Google Cloud Services
# ------------------------------------------------------------------------------
resource "google_project_service" "iam" {
  project                    = var.project_id
  service                    = "iam.googleapis.com"
  disable_dependent_services = false
  disable_on_destroy         = false # Set to true if you want to disable on destroy
}
resource "google_project_service" "apigee" {
  project                    = var.project_id
  service                    = "apigee.googleapis.com"
  disable_dependent_services = false
  disable_on_destroy         = false
}
resource "google_project_service" "compute" {
  project                    = var.project_id
  service                    = "compute.googleapis.com"
  disable_dependent_services = false
  disable_on_destroy         = false
}
resource "google_project_service" "apigeeconnect" {
  project                    = var.project_id
  service                    = "apigeeconnect.googleapis.com"
  disable_dependent_services = false
  disable_on_destroy         = false
}
resource "google_project_service" "container" { # Often needed for GKE, even if using AKS for runtime, Apigee might interact
  project                    = var.project_id
  service                    = "container.googleapis.com"
  disable_dependent_services = false
  disable_on_destroy         = false
}
# Add other services like storage, logging, monitoring if not already enabled
resource "google_project_service" "storage" {
  project                    = var.project_id
  service                    = "storage.googleapis.com"
  disable_dependent_services = false
  disable_on_destroy         = false
}
resource "google_project_service" "logging" {
  project                    = var.project_id
  service                    = "logging.googleapis.com"
  disable_dependent_services = false
  disable_on_destroy         = false
}
resource "google_project_service" "monitoring" {
  project                    = var.project_id
  service                    = "monitoring.googleapis.com"
  disable_dependent_services = false
  disable_on_destroy         = false
}
# ------------------------------------------------------------------------------
# Create Apigee Non-Prod Service Account
# ------------------------------------------------------------------------------
resource "google_service_account" "apigee_non_prod_sa" {
  project      = var.project_id
  account_id   = local.service_account_id_short
  display_name = "Apigee Hybrid Non-Prod SA"
  description  = "Service account for Apigee Hybrid non-production workloads"

  depends_on = [
    google_project_service.iam, # Ensure IAM API is enabled
  ]
}

resource "google_project_iam_member" "apigee_non_prod_sa_bindings" {
  for_each = toset(local.apigee_non_prod_sa_roles)
  project  = var.project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.apigee_non_prod_sa.email}"
  depends_on = [
    google_service_account.apigee_non_prod_sa,
    # Add dependencies on the specific services if roles grant permissions on them
    google_project_service.apigee,
    google_project_service.apigeeconnect,
    google_project_service.storage,
    google_project_service.logging,
    google_project_service.monitoring,
  ]
}

resource "google_service_account_key" "apigee_non_prod_sa_key" {
  service_account_id = google_service_account.apigee_non_prod_sa.name
}

# Ensure the output directory exists
resource "null_resource" "create_output_dir" {
  triggers = {
    output_dir_path = local.output_dir
  }
  provisioner "local-exec" {
    command = "mkdir -p ${local.output_dir}"
  }
}

# Save the service account key to a local file
resource "local_file" "apigee_non_prod_sa_key_file" {
  sensitive_content = base64decode(google_service_account_key.apigee_non_prod_sa_key.private_key)
  filename          = "${local.output_dir}/${local.service_account_id_short}-sa-key.json"
  file_permission   = "0600"
  depends_on = [
    null_resource.create_output_dir,
    google_service_account_key.apigee_non_prod_sa_key,
  ]
}

# ------------------------------------------------------------------------------
# Self-Signed TLS Certificate for Apigee Environment Group Hostnames
# ------------------------------------------------------------------------------
resource "tls_private_key" "apigee_envgroup_key" {
  count     = var.tls_apigee_self_signed ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "apigee_envgroup_cert" {
  count           = var.tls_apigee_self_signed ? 1 : 0
  private_key_pem = tls_private_key.apigee_envgroup_key[0].private_key_pem
  dns_names       = var.apigee_envgroup_hostnames

  subject {
    common_name  = local.primary_hostname_for_cert
    organization = "Apigee Hybrid Self-Signed Cert"
  }

  validity_period_hours = 8760 # 1 year
  early_renewal_hours   = 720  # 30 days

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

resource "local_file" "apigee_envgroup_private_key_file" {
  sensitive_content  = var.tls_apigee_self_signed ? tls_private_key.apigee_envgroup_key[0].private_key_pem : var.tls_apigee_key_path
  filename        = "${local.output_dir}/${local.cert_filename_prefix}.key"
  file_permission = "0600"
  depends_on = [
    null_resource.create_output_dir,
    tls_private_key.apigee_envgroup_key,
  ]
}

resource "local_file" "apigee_envgroup_cert_file" {
  content         = var.tls_apigee_self_signed ? tls_self_signed_cert.apigee_envgroup_cert[0].cert_pem : var.tls_apigee_cert_path
  filename        = "${local.output_dir}/${local.cert_filename_prefix}.crt"
  file_permission = "0644"
  depends_on = [
    null_resource.create_output_dir,
    tls_self_signed_cert.apigee_envgroup_cert,
  ]
}

# ------------------------------------------------------------------------------
# Apigee Organization, Environment, EnvGroup, Attachment
# ------------------------------------------------------------------------------
resource "google_apigee_organization" "apigee_org" {
  count = var.create_org ? 1 : 0

  project_id       = var.project_id # The GCP project that will host the Apigee org
  display_name     = var.apigee_org_display_name != "" ? var.apigee_org_display_name : "Apigee Org for ${var.project_id}"
  description      = "Apigee Hybrid Organization managed by Terraform"
  analytics_region = var.region
  runtime_type     = "HYBRID"
  billing_type     = var.billing_type

  depends_on = [
    google_project_service.apigee,
    google_project_service.compute,
    google_project_service.container, # Apigee may require container API for its operations
    local_file.apigee_non_prod_sa_key_file, # Ensure SA Key is created before org

  ]
}

resource "google_apigee_environment" "hybrid_env" {
  count = var.create_org ? 1 : 0

  name         = local.effective_env_name
  display_name = var.apigee_env_display_name
  description  = "Hybrid Environment for ${local.effective_env_name}"
  org_id       = local.effective_org_id
}

resource "google_apigee_envgroup" "hybrid_envgroup" {
  count = var.create_org ? 1 : 0

  name      = local.effective_envgroup_name
  hostnames = local.effective_envgroup_hostnames
  org_id    = local.effective_org_id

  depends_on = [
    google_apigee_organization.apigee_org,
    google_project_service.apigee,
  ]
}

resource "google_apigee_envgroup_attachment" "env_to_group_attachment" {
  count = var.create_org ? 1 : 0

  envgroup_id = google_apigee_envgroup.hybrid_envgroup[0].id
  environment = google_apigee_environment.hybrid_env[0].name

  depends_on = [
    google_apigee_environment.hybrid_env,
    google_apigee_envgroup.hybrid_envgroup,
  ]
}
# ------------------------------------------------------------------------------
# Generate overrides.yaml and apigee-service.yaml
# ------------------------------------------------------------------------------

resource "local_file" "apigee_overrides" {
  content = templatefile(local.final_overrides_template_path, {
    # K8S_CLUSTER_RUNNING_APIGEE_RUNTIME
    instance_id                       = var.apigee_instance_name # This is the Apigee Instance name (google_apigee_instance.name)
    apigee_namespace                  = var.apigee_namespace
    # GCP_PROJECT_ID used for Apigee Organization
    project_id                        = var.project_id
    analytics_region                  = var.region
    # K8S_CLUSTER_NAME where Apigee is installed
    cluster_name                      = var.cluster_name
    cluster_location                  = var.region # Assuming K8s cluster region is same as Apigee region for simplicity
    # APIGEE_ORGANIZATION_ID
    org_name                          = local.org_name_for_overrides # This should be the Apigee Org ID (typically project_id)
    environment_name                  = var.apigee_env_name
    cassandra_replica_count           = var.apigee_cassandra_replica_count
    # File paths for SA key and certs are basenames, script will handle full paths for secrets
    non_prod_service_account_filepath = local.sa_key_filename_for_overrides
    ingress_name                      = var.ingress_name
    environment_group_name            = var.apigee_envgroup_name
    ssl_cert_path                     = local.cert_file_path_for_overrides
    ssl_key_path                      = local.private_key_file_path_for_overrides
    ingress_svc_annotations_yaml      = local.ingress_svc_annotations_yaml # Pass the generated YAML snippet
    # Add any other variables your template needs
  })
  filename        = "${local.output_dir}/overrides.yaml"
  file_permission = "0644"
  depends_on = [
    null_resource.create_output_dir,
    local_file.apigee_non_prod_sa_key_file, # Ensure SA key file is written
    local_file.apigee_envgroup_cert_file,   # Ensure cert file is written
    local_file.apigee_envgroup_private_key_file, # Ensure key file is written
  ]
}

resource "local_file" "apigee_service" {
  content = templatefile(local.final_service_template_path, {
    apigee_namespace       = var.apigee_namespace
    # APIGEE_ORGANIZATION_ID
    org_name               = local.org_name_for_overrides # This should be the Apigee Org ID
    ingress_name           = var.ingress_name
    # SERVICE_NAME often maps to envgroup name or a specific service identifier
    service_name           = var.apigee_envgroup_name # Or another appropriate variable
    apigee_lb_ip           = var.apigee_lb_ip
    # Add any other variables your template needs
  })
  filename        = "${local.output_dir}/apigee-service.yaml"
  file_permission = "0644"
  depends_on = [null_resource.create_output_dir]
}

# ------------------------------------------------------------------------------
# Execute Apigee Setup Script
# ------------------------------------------------------------------------------
resource "null_resource" "apigee_setup_execution" {
  count = var.apigee_install ? 1 : 0

  triggers = {
    apigee_version                   = var.apigee_version
    apigee_namespace                 = var.apigee_namespace
    kubeconfig                       = var.kubeconfig
    apigee_overrides_yaml_content    = local_file.apigee_overrides.content
    apigee_service_yaml_content      = local_file.apigee_service.content
    apigee_sa_key_json_content       = local_file.apigee_non_prod_sa_key_file.content
    apigee_envgroup_cert_content     = local_file.apigee_envgroup_cert_file.content
    apigee_envgroup_key_content      = local_file.apigee_envgroup_private_key_file.content
    script_hash                      = filemd5("${path.module}/setup_apigee.sh")
    output_dir                       = local.output_dir
  }

  provisioner "local-exec" {
    when = destroy
    #command = "kubectl delete -f ${self.triggers.output_dir}/apigee-service.yaml"
    command = "if [ -n \"${self.triggers.kubeconfig}\" ] && [ -f \"${self.triggers.kubeconfig}\" ]; then export KUBECONFIG=${self.triggers.kubeconfig}; fi && kubectl delete -f ${self.triggers.output_dir}/apigee-service.yaml"
    on_failure = continue
  }
  
  provisioner "local-exec" {
    command = <<-EOT
      bash ${path.module}/setup_apigee.sh \
        --version "${var.apigee_version}" \
        --namespace "${var.apigee_namespace}" \
        --kubeconfig "${var.kubeconfig}" \
        --sa_email "${local.service_account_email}" \
        --overrides "${abspath(local_file.apigee_overrides.filename)}" \
        --service "${abspath(local_file.apigee_service.filename)}" \
        --key "${abspath(local_file.apigee_non_prod_sa_key_file.filename)}" \
        --cert "${abspath(local_file.apigee_envgroup_cert_file.filename)}" \
        --private-key "${abspath(local_file.apigee_envgroup_private_key_file.filename)}"
    EOT
  }

  depends_on = [
    google_apigee_envgroup_attachment.env_to_group_attachment,
    local_file.apigee_overrides,
    local_file.apigee_service,
    local_file.apigee_non_prod_sa_key_file,
    local_file.apigee_envgroup_cert_file,
    local_file.apigee_envgroup_private_key_file,
  ]
}