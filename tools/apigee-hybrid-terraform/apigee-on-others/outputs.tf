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