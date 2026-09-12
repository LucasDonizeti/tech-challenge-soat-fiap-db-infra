output "rds_endpoint" {
  description = "Endpoint do RDS para a aplicação"
  value       = module.rds.endpoint
  sensitive   = true
}

output "rds_port" {
  description = "Porta do RDS"
  value       = module.rds.port
}
