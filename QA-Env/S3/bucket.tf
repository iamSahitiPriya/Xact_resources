provider "aws" {
  region = var.aws_region
}

resource "aws_s3_bucket" "xact-app-qa" {
  bucket = var.bucket_name
  tags = {
    Environment = "QA"
  }
}
resource "aws_s3_bucket_public_access_block" "xact-app-qa" {
  bucket = aws_s3_bucket.xact-app-qa.id

  block_public_acls   = true
  block_public_policy = true
  restrict_public_buckets = true
  ignore_public_acls = true
}