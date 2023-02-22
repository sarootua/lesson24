# Configure the Hashicorp Provider
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.5"
    }
  }
  required_version = "~> 1.3"
}

# Configure the AWS Provider
variable "profile" {
  type    = string
  default = "default"
}
variable "region" {
  type    = string
  default = "us-east-1"
}
provider "aws" {
  profile = var.profile
  region  = var.region
}

# Variable of S3 bucket name
variable "bucket_name" {
  type    = string
  default = "hillel241114"
}

module "lesson24" {
  source      = "./module/lesson24"
  bucket_name = var.bucket_name
}

output "distribution_domain_name" {
  value = module.lesson24.distribution_domain_name
}