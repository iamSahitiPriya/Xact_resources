variable "aws_region" {
  description = "AWS region to create resources"
  default     = "ap-south-1"
}

variable "username" {
  description = "Default password"
  default     = "fake-username"
}

variable "password" {
  description = "Default password"
  default     = "fake-password"
}

variable "username_np" {
  description = "Default password for non prod"
  default     = "fake-username"
}

variable "password_np" {
  description = "Default password non prod"
  default     = "fake-password"
}

variable "vpc_id" {
  description = "VPC for PostgreSql"
}

variable "cidr_block" {
  description = "CIDR Block to allow PostgreSql Access"
}
