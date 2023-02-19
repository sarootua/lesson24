# Set global variable: profile_name and region
module "global_variable" {
  source = "./module/"
}

# Variable of S3 bucket name
variable "bucket_name" {
  type        = string
  default     = "test1111111sss"
  description = "Name of the S3 bucket"
}

# Create a Bucket
resource "aws_s3_bucket" "my_bucket" {
  bucket = var.bucket_name
  tags = {
     School = "ithillel"
     Lesson = "lesson24"
   }
}

# Create a Bucket Policy to allow CloudFront to access the S3 bucket
resource "aws_s3_bucket_policy" "my_bucket_policy" {
  bucket = aws_s3_bucket.my_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = aws_cloudfront_origin_access_identity.my_oai.iam_arn
        }
        Action = "s3:GetObject"
        Resource = "${aws_s3_bucket.my_bucket.arn}/*"
      }
    ]
  })
}

# Create an Origin Access Identity
resource "aws_cloudfront_origin_access_identity" "my_oai" {
  comment = "My CloudFront Origin Access Identity"
}

# Create a CloudFront distribution
resource "aws_cloudfront_distribution" "my_distrib" {
  origin {
    domain_name = aws_s3_bucket.my_bucket.bucket_regional_domain_name
    origin_id   = aws_s3_bucket.my_bucket.id
    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.my_oai.cloudfront_access_identity_path
    }
  }
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Some comment"
  default_root_object = "index.html"

  default_cache_behavior {
    target_origin_id = aws_s3_bucket.my_bucket.id
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods   = ["GET", "HEAD", "OPTIONS"]
    cached_methods    = ["GET", "HEAD"]

    # Set header policy
    response_headers_policy_id = aws_cloudfront_response_headers_policy.my_header.id
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
    min_ttl = 0
    default_ttl = 3600
    max_ttl = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

# Create a CloudFront security headers policy
resource "aws_cloudfront_response_headers_policy" "my_header" {
  name = "policy-${aws_s3_bucket.my_bucket.id}"
  security_headers_config {
    content_type_options {
      override = true
    }
    frame_options {
      frame_option = "DENY"
      override = true
    }
    referrer_policy {
      referrer_policy = "same-origin"
      override = true
    }
    xss_protection {
      mode_block = true
      protection = true
      override = true
    }
    strict_transport_security {
      access_control_max_age_sec = "63072000"
      include_subdomains = true
      preload = true
      override = true
    }
    content_security_policy {
      content_security_policy = "frame-ancestors 'none'; default-src 'none'; img-src 'self'; script-src 'self'; style-src 'self'; object-src 'none'"
      override = true
    }
  }
}

output "distribution_domain_name" {
  value = aws_cloudfront_distribution.my_distrib.domain_name
}