# Security Group — permite acesso somente a partir dos nodes do EKS
resource "aws_security_group" "rds" {
  name        = "${var.name}-sg"
  description = "Acesso ao RDS somente dos nodes EKS"
  vpc_id      = var.vpc_id

  ingress {
    description     = "MySQL dos nodes EKS"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [var.eks_node_sg_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name}-sg" })
}

# https://registry.terraform.io/modules/terraform-aws-modules/rds/aws/latest
module "db" {
  source = "terraform-aws-modules/rds/aws"

  identifier        = var.name
  engine            = "mysql"
  engine_version    = "8.0"
  instance_class    = "db.t3.micro"
  allocated_storage = 20

  db_name  = var.db_name
  username = var.db_username
  port     = 3306

  manage_master_user_password = true

  db_subnet_group_name   = var.db_subnet_group_name
  vpc_security_group_ids = [aws_security_group.rds.id]

  multi_az = false

  backup_retention_period = 1
  backup_window           = "03:00-06:00"
  maintenance_window      = "Mon:00:00-Mon:03:00"

  family               = "mysql8.0"
  major_engine_version = "8.0"

  parameters = [
    { name = "character_set_client", value = "utf8mb4" },
    { name = "character_set_server", value = "utf8mb4" }
  ]

  deletion_protection = false

  create_monitoring_role = false

  tags = var.tags
}
