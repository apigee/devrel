# GCP Configuration
project_id = "apigee-gke-example7"
region     = "us-central1"

# Apigee Configuration
apigee_org_name          = "apigee-gke-example7" #Same as Projectid
apigee_env_name          = "dev"
apigee_envgroup_name     = "dev-group"
apigee_namespace         = "apigee"
apigee_version           = "1.15.0"
apigee_org_display_name  = "Apigee GKE Example Organization"
apigee_env_display_name  = "Development Environment"
apigee_instance_name     = "apigee-instance"
apigee_cassandra_replica_count = 3

# Hostnames for Apigee Environment Group
hostnames = [
  "api.example.com",
  "api-dev.example.com"
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
  # "cloud.google.com/neg" = "{\"ingress\": true}"
  # "cloud.google.com/load-balancer-type" = "Internal"
}

# Optional: Paths to template files if you want to use custom templates
# overrides_template_path = "path/to/overrides-template.yaml"
# service_template_path   = "path/to/service-template.yaml"

# Billing Configuration
billing_type = "EVALUATION"  # or "PAID" 
