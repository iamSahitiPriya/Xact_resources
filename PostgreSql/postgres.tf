terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "3.47.0"
    }
  }
}


provider "aws" {
  region = var.aws_region
}

provider "random" {
  # Configuration options
}

resource "random_password" "password" {
  length = 20
  special = false
  override_special = "_%@"
}

resource "aws_db_instance" "default" {
  allocated_storage    = 20
  engine               = "postgres"
  identifier           =  "dev-db"
  engine_version       = "13"
  instance_class       = "db.t3.medium"
  name                 = "ntweeklydb001"
  username             = "dbadmin1"
  password             = random_password.password.result
  skip_final_snapshot  = true
  publicly_accessible  = true

}
