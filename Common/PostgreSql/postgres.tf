terraform {
  required_version = ">= 0.12"
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "3.47.0"
    }
    postgresql = {
      source = "cyrilgdn/postgresql"
      version = "1.15.0"
    }

  }
}


provider "aws" {
  region = var.aws_region
}

resource "aws_security_group" "rds_sg_np" {
  name        = "rds_sg_np"
  description = "Allow PostgreSql Traffic"
  vpc_id      = var.vpc_id

  ingress {
    description      = "Allow from Personal CIDR block"
    from_port        = 5432
    to_port          = 5432
    protocol         = "tcp"
    cidr_blocks      = [var.cidr_block]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "PostgreSql RDS SG NON PROD"
  }
}


resource "aws_db_instance" "xact-db_non_prod" {
  allocated_storage    = 20
  engine               = "postgres"
  identifier           =  "xact-db-np"
  engine_version       = "14"
  instance_class       = "db.t3.small"
  name                 = "xactnonprod"
  username             = var.username_np
  password             = var.password_np
  vpc_security_group_ids = [aws_security_group.rds_sg_np.id]
  skip_final_snapshot  = true
  publicly_accessible  = false
  storage_encrypted = true
}


resource "aws_security_group" "rds_sg_prod" {
  name        = "rds_sg_prod"
  description = "Allow PostgreSql Traffic"
  vpc_id      = var.vpc_id

  ingress {
    description      = "Allow from Personal CIDR block"
    from_port        = 5432
    to_port          = 5432
    protocol         = "tcp"
    cidr_blocks      = [var.cidr_block]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "PostgreSql RDS SG PROD"
  }
}


resource "aws_db_instance" "xact-db_prod" {
  allocated_storage    = 20
  engine               = "postgres"
  identifier           =  "xact-db-prod"
  engine_version       = "14"
  instance_class       = "db.t3.medium"
  name                 = "xactprod"
  username             = var.username
  password             = var.password
  vpc_security_group_ids = [aws_security_group.rds_sg_prod.id]
  skip_final_snapshot  = true
  publicly_accessible  = false
  storage_encrypted = true
}
