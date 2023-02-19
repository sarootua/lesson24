variable "profile_name" {
  type    = string
  default = "default"
}

variable "region" {
  type    = string
  default = "us-east-1"
}

provider "aws" {
  profile = var.profile_name
  region  = var.region
}