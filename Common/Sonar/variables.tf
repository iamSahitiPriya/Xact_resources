variable "aws_region" {
  description = "AWS region to create resources"
  default     = "ap-south-1"
}

variable "vpc_id" {
  description = "VPC for Sonar"
}

variable "cidr_block" {
  description = "CIDR Block to allow Sonar Access"
}

variable "key_name" {
  description = "Name of keypair to ssh"
}
