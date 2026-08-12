variable "name" { type = string }
variable "db_name" { type = string }
variable "db_username" { type = string }
variable "subnet_ids" { type = list(string) }
variable "db_subnet_group_name" { type = string }
variable "vpc_id" { type = string }
variable "eks_node_sg_id" {
  description = "Security group dos nodes EKS para permitir acesso ao RDS"
  type        = string
}
variable "tags" {
  type    = map(string)
  default = {}
}
