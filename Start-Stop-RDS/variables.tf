variable "aws_region" {
  default = "ap-south-1"
}

variable "start_stop_rds_key" {
  description = "Key for non-prod RDS instances"
}

variable "start_stop_rds_value" {
  description = "Value for non-prod RDS instances"
}
