data "terraform_remote_state" "k8s" {
  backend = "s3"

  config = {
    bucket = "bucket-tfstate-1029"
    key    = "global/s3/terraform.tfstate"
    region = var.region
  }
}

module "rds" {
  source = "./modules/rds"

  name                 = "${var.app_name}-rds"
  db_name              = var.db_name
  db_username          = var.db_username
  subnet_ids           = data.terraform_remote_state.k8s.outputs.database_subnets
  db_subnet_group_name = data.terraform_remote_state.k8s.outputs.db_subnet_group_name
  vpc_id               = data.terraform_remote_state.k8s.outputs.vpc_id
  eks_node_sg_id       = data.terraform_remote_state.k8s.outputs.eks_node_security_group_id

  tags = { Project = var.app_name }
}
