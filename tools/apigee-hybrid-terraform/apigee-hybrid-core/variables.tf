#######################################
#### GCP/Apigee Specific variables ####
#######################################

variable "project_id" {
  description = "The GCP project ID where Apigee Hybrid will be set up."
  type        = string
}

variable "region" {
  description = "The GCP region for Apigee resources like analytics and runtime instance location."
  type        = string
  default     = "us-central1"
}

variable "apigee_org_display_name" {
  description = "Display name for the Apigee Organization. If create_org is true, this will be used."
  type        = string
  default     = "Apigee Hybrid Organization" # Generic default
}

variable "apigee_env_name" {
  description = "Name for the Apigee Environment (e.g., dev, test, prod)."
  type        = string
  default     = "dev"
}

variable "kubeconfig" {
  description = "Path to the Kubernetes configuration file."
  type        = string
  default     = ""
}


variable "apigee_env_display_name" {
  description = "Display name for the Apigee Environment."
  type        = string
  default     = "Development Environment"
}

variable "apigee_instance_name" {
  description = "Name for the Apigee Runtime Instance (representing your K8s cluster)."
  type        = string
  default     = "hybrid-instance-1"
}

variable "apigee_envgroup_name" {
  description = "Name for the Apigee Environment Group."
  type        = string
  default     = "api-proxy-group"
}

variable "apigee_envgroup_hostnames" {
  description = "List of hostnames for the Environment Group."
  type        = list(string)
  # Example: default = ["api.example.com"] # Must be provided by calling module
}

variable "apigee_cassandra_replica_count" {
  description = "Cassandra Replica Count."
  type        = number
  default     = 1 # For non-prod; adjust for prod
}

variable "apigee_install" {
  description = "Indicates whether to run the Apigee setup script. Set to true to install Apigee, false otherwise."
  type        = bool
  default     = true
}

variable "create_org" {
  description = "Indicates whether to create the Apigee organization. Set to true to create, false if it already exists."
  type        = bool
  default     = false # Safer default; often org exists or is managed separately
}

variable "billing_type" {
  description = "Billing type for the Apigee organization (EVALUATION or PAID). Only used if create_org is true."
  type        = string
  default     = "EVALUATION"
  validation {
    condition     = contains(["EVALUATION", "PAID", "SUBSCRIPTION"], var.billing_type)
    error_message = "Billing type must be EVALUATION, PAID or SUBSCRIPTION."
  }
}

variable "overrides_template_path" {
  description = "Path to the overrides template file (e.g., overrides-templates.yaml)."
  type        = string
  default     = "" # Will be set to path.module in main.tf if not overridden
}

variable "apigee_service_account_name" {
  description = "The name of the service account"
  type        = string
  default     = "apigee-svc-tf" # Will be set to path.module in main.tf if not overridden
}

variable "service_template_path" {
  description = "Path to the Apigee service template file (e.g., apigee-service-template.yaml)."
  type        = string
  default     = "" # Will be set to path.module in main.tf if not overridden
}

variable "apigee_namespace" {
  description = "The Kubernetes namespace where Apigee components will be deployed."
  type        = string
  default     = "apigee"
}

variable "ingress_name" {
  description = "Name for the ingress gateway (max 17 characters)."
  type        = string
  default     = "apigee-ingress"
  validation {
    condition     = length(var.ingress_name) <= 17
    error_message = "Ingress name must be 17 characters or less."
  }
}

variable "ingress_svc_annotations" {
  description = "A map of annotations to apply to the ingress gateway service. Example: { \"service.beta.kubernetes.io/azure-load-balancer-internal\": \"true\" }"
  type        = map(string)
  default     = {}
}

variable "apigee_version" {
  description = "Version of Apigee Hybrid to install."
  type        = string
  # Example: default = "1.14.2-hotfix.1" # Must be provided by calling module
}

variable "cluster_name" {
  description = "Name of the Kubernetes cluster where Apigee Hybrid will be deployed. Used in overrides.yaml."
  type        = string
  # Example: "aks-apigee-cluster" # Must be provided by calling module
}

variable "apigee_org_name" {
  description = "Name of the Apigee organization. Typically the GCP Project ID. Used in overrides.yaml."
  type        = string
  # If not provided, project_id will be used.
  default = ""
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
