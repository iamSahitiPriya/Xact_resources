provider "aws" {
  region = var.aws_region
}

resource "aws_s3_bucket" "xact-app-dev" {
  bucket = var.bucket_name
  tags = {
    Environment = "Dev"
  }
}
resource "aws_s3_bucket_public_access_block" "xact-app-dev" {
  bucket = aws_s3_bucket.xact-app-dev.id

  block_public_acls   = true
  block_public_policy = true
  restrict_public_buckets = true
  ignore_public_acls = true
}

resource "aws_cloudfront_distribution" "dev_distribution" {
  origin {
    origin_id   = aws_s3_bucket.xact-app-dev.id
    domain_name = aws_s3_bucket.xact-app-dev.bucket_regional_domain_name
  }
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "CloudFront distribution for Development"
  default_root_object = "index.html"

  aliases = ["dev.project-xact.in"]
  custom_error_response {
    error_code = 403
    response_code = 200
    response_page_path = "/index.html"
  }
  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = aws_s3_bucket.xact-app-dev.id
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
    Environment = "Dev"
  }
  viewer_certificate {
    acm_certificate_arn = "arn:aws:acm:us-east-1:730911736748:certificate/d3d78241-e69f-4979-bd54-ccfc02d4d4e2"
    ssl_support_method = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}