variable "region" {
  description = "Região AWS"
  type        = string
  default     = "us-east-1"
}

variable "app_name" {
  description = "Nome da aplicação (usado como prefixo nos recursos)"
  type        = string
  default     = "oficina"
}

variable "db_username" {
  description = "Usuário master do RDS"
  type        = string
  default     = "admindb"
  sensitive   = true
}

variable "db_name" {
  description = "Nome do banco de dados"
  type        = string
  default     = "oficina"
}
