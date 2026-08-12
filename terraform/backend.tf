terraform {
  backend "s3" {
    bucket       = "bucket-tfstate-1029"
    key          = "db/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}
