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
  #policy = "${data.template_file.bucket-policy.rendered}"
  policy = templatefile("${path.module}/tpl/bucket-policy.json", {
    bucket_arn          = "${aws_s3_bucket.bucket.arn}/*"
    distribution_arn    = "${aws_cloudfront_distribution.distribution.arn}"
  })
  depends_on = [
    aws_cloudfront_distribution.distribution,
    aws_s3_bucket.bucket
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

module "headers_policy" {
  source = "./tpl"
  bucket_id = aws_s3_bucket.bucket.id
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
    response_headers_policy_id = module.headers_policy.headers_policy_id
    target_origin_id = aws_s3_bucket.bucket.id
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods   = ["GET", "HEAD", "OPTIONS"]
    cached_methods    = ["GET", "HEAD"]

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
    module.headers_policy
  ]
}

output "distribution_domain_name" {
  value = aws_cloudfront_distribution.distribution.domain_name
}

################## data ##################
#data "template_file" "bucket-policy" {
#  template = "${file("${path.module}/tpl/bucket-policy.json")}"
#
#  vars = {
#    bucket_arn          = "${aws_s3_bucket.bucket.arn}/*"
#    distribution_arn    = "${aws_cloudfront_distribution.distribution.arn}"
#  }
#}

