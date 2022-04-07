variable "aws_region" {
  default = "ap-south-1"
}

variable "vpc_id" {
  description = "VPC for ECS"
}

variable "cidr_block" {
  description = "CIDR Block to allow ECS Access"
}

variable "environment" {
  description = "Service environment"
}

variable "account" {
  description = "Account number"
}

variable "DB_USER" {
  description = "ssm path of param"
}

variable "DB_PWD" {
  description = "ssm path of param"
}

variable "OIDC_ISSUER" {
  description = "OIDC Issuer for validating Access Token"
}
variable "aws_access_key" {
  description = "access key for our bucket"
}
variable "aws_secret_key" {
  description = "secret key"
}