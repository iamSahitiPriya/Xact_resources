terraform {
  required_version = ">= 0.15"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0.0"
    }
  }

  backend "s3" {
    bucket         = "xact-infra-remote-state-qa"
    key = "s3/terraform.tfstate"
    region         = "ap-south-1"
    encrypt        = true
  }
}

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

resource "aws_cloudfront_distribution" "qa_distribution" {
  origin {
    origin_id   = aws_s3_bucket.xact-app-qa.id
    domain_name = aws_s3_bucket.xact-app-qa.bucket_regional_domain_name
  }
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "CloudFront distribution for QA"
  default_root_object = "index.html"

  aliases = ["qa.xact.thoughtworks.net"]
  custom_error_response {
    error_code = 403
    response_code = 200
    response_page_path = "/index.html"
  }
  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = aws_s3_bucket.xact-app-qa.id
    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "https-only"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  price_class = "PriceClass_200"


  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  tags = {
    Environment = "Qa"
  }
  viewer_certificate {
    acm_certificate_arn = "arn:aws:acm:us-east-1:730911736748:certificate/c1998ccf-65ac-4de3-a8b2-d4fec167575a"
    ssl_support_method = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}
