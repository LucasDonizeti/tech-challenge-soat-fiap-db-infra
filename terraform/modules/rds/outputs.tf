output "endpoint" {
  description = "Endpoint do RDS (host)"
  value       = module.db.db_instance_address
  sensitive   = true
}

output "port" {
  value = module.db.db_instance_port
}

output "secret_arn" {
  description = "ARN do secret no Secrets Manager com a senha do banco"
  value       = module.db.db_instance_master_user_secret_arn
  sensitive   = true
}
