variable "aws_region" {
  default     = "ap-south-1"
}

variable "vpc_id" {
  description = "VPC for ECS"
}

variable "cidr_block" {
  description = "CIDR Block to allow ECS Access"
}

