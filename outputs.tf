output "alb_dns_name" {
  description = "ALB DNS name"
  value       = module.compute.alb_dns_name
}

output "rds_endpoint" {
  description = "RDS endpoint"
  value       = module.database.rds_endpoint
  sensitive   = true
}

output "s3_bucket_name" {
  description = "S3 bucket name"
  value       = module.storage.bucket_id
}

output "workspace" {
  description = "Active workspace"
  value       = terraform.workspace
}

output "secrets_manager_secret_name" {
  description = "Secrets Manager secret name"
  value       = module.database.secret_name
}
