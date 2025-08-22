output "apigee_non_prod_sa_email" {
  description = "Email of the Apigee Non-Prod service account."
  value       = google_service_account.apigee_non_prod_sa.email
}

output "apigee_non_prod_sa_key_path" {
  description = "Path to the saved Apigee Non-Prod service account key file."
  value       = local_file.apigee_non_prod_sa_key_file.filename
}

output "apigee_overrides_yaml_path" {
  description = "Path to the generated Apigee Hybrid overrides.yaml file."
  value       = local_file.apigee_overrides.filename
}

output "apigee_service_yaml_path" {
  description = "Path to the generated Apigee Hybrid apigee-service.yaml file."
  value       = local_file.apigee_service.filename
}

output "apigee_envgroup_private_key_file_path" {
  description = "Path to the self-signed private key file for the Apigee envgroup hostname(s)."
  value       = local_file.apigee_envgroup_private_key_file.filename
}

output "apigee_envgroup_cert_file_path" {
  description = "Path to the self-signed certificate file for the Apigee envgroup hostname(s)."
  value       = local_file.apigee_envgroup_cert_file.filename
}

output "apigee_setup_script_executed_trigger" {
  description = "Indicates if the Apigee setup script was triggered. This output changes if the script's triggers change."
  value       = var.apigee_install ? null_resource.apigee_setup_execution[0].id : "Apigee setup script was skipped (apigee_install=false)."
}

output "apigee_organization_id" {
  description = "The ID of the Apigee organization."
  value       = local.effective_org_id
}

output "apigee_environment_name" {
  description = "The name of the Apigee environment."
  value       = local.effective_env_name
}

output "apigee_envgroup_id" {
  description = "The ID of the Apigee environment group."
  value       = local.effective_envgroup_id
}
