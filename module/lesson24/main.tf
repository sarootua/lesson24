################## s3 bucket ##################
variable "bucket_name" {
  type    = string
}

resource "aws_s3_bucket" "bucket" {
  bucket = var.bucket_name
  tags = {
    School = "ithillel"
    Lesson = "lesson24"
  }
}

resource "aws_s3_bucket_acl" "bucket_acl" {
  bucket = aws_s3_bucket.bucket.id
  acl    = "private"
  depends_on = [aws_s3_bucket.bucket]
}

resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket = aws_s3_bucket.bucket.id
  policy = "${data.template_file.bucket-policy.rendered}"

  depends_on = [
    aws_cloudfront_distribution.distribution,
    aws_s3_bucket.bucket,
    data.template_file.bucket-policy
  ]
}

################## cloud front ##################
resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "OAC_S3 ${aws_s3_bucket.bucket.id}"
  description                       = "Managed by ${aws_s3_bucket.bucket.tags.School}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
  depends_on = [aws_s3_bucket.bucket]
}

resource "aws_cloudfront_response_headers_policy" "headers_policy" {
  name = "policy-${aws_s3_bucket.bucket.id}"

  security_headers_config {
    content_type_options {
      override = true
    }
    frame_options {
      frame_option = "DENY"
      override     = true
    }
    referrer_policy {
      referrer_policy = "same-origin"
      override        = true
    }
    xss_protection {
      mode_block = true
      protection = true
      override   = true
    }
    strict_transport_security {
      access_control_max_age_sec = "63072000"
      include_subdomains         = true
      preload                    = true
      override                   = true
    }
    content_security_policy {
      content_security_policy = "frame-ancestors 'none'; default-src 'none'; img-src 'self'; script-src 'self'; style-src 'self'; object-src 'none'"
      override                = true
    }
  }

  depends_on = [aws_s3_bucket.bucket]
}

resource "aws_cloudfront_distribution" "distribution" {
  origin {
    domain_name = aws_s3_bucket.bucket.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
    origin_id   = aws_s3_bucket.bucket.id
  }
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  default_cache_behavior {
    target_origin_id = aws_s3_bucket.bucket.id
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods   = ["GET", "HEAD", "OPTIONS"]
    cached_methods    = ["GET", "HEAD"]

    # Set header policy
    response_headers_policy_id = aws_cloudfront_response_headers_policy.headers_policy.id
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
  depends_on = [
    aws_cloudfront_origin_access_control.oac,
    aws_cloudfront_response_headers_policy.headers_policy
  ]
}

output "distribution_domain_name" {
  value = aws_cloudfront_distribution.distribution.domain_name
}

################## data ##################
data "template_file" "bucket-policy" {
  template = "${file("${path.module}/bucket-policy.json")}"

  vars = {
    bucket_arn          = "${aws_s3_bucket.bucket.arn}/*"
    distribution_arn    = "${aws_cloudfront_distribution.distribution.arn}"
  }
}
