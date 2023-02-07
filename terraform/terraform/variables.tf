# -------------------------------------------------------------
# Elastic configuration
# -------------------------------------------------------------
variable "elastic_version" {
  type = string
  default = "8.5.3"
}

variable "elastic_region" {
  type = string
  default = "eu-west-2"
}

variable "elastic_deployment_name" {
  type = string
  default = "AWS Workshop"
}

variable "elastic_deployment_template_id" {
  type = string
  default = "aws-general-purpose"
}

# -------------------------------------------------------------
# AWS configuration
# -------------------------------------------------------------

variable "aws_region" {
  type = string
  default = "eu-west-1"
}

variable "aws_access_key" {
  type = string
}

variable "aws_secret_key" {
  type = string
}

variable "bucket_name" {
  type = string
  default = "elastic-sar-bucket"
}

variable "mapped_elastic_region" {
  type = map(string)
  default = {
    "af-south-1" = "aws-af-south-1"
    "ap-east-1" = "aws-ap-east-1"
    "ap-northeast-1" = "ap-northeast-1"
    "ap-northeast-2" = "aws-ap-northeast-2"
    "ap-south-1" =     "aws-ap-south-1"
    "ap-southeast-1" = "ap-southeast-1"
    "ap-southeast-2" = "ap-southeast-2"
    "eu-central-1" = "aws-eu-central-1"
    "eu-south-1" =     "aws-eu-south-1"
    "eu-west-1" =     "eu-west-1"
    "eu-west-2" =     "aws-eu-west-2"
    "eu-west-3" =     "aws-eu-west-3"
    "me-south-1" =     "aws-me-south-1"
    "sa-east-1" =     "sa-east-1"
    "us-east-1" =     "us-east-1"
    "us-east-2" =     "aws-us-east-2"
    "us-west-1" =     "us-west-1"
    "us-west-2" =     "us-west-2"
    "ca-central-1" = "aws-ca-central-1"
  }
}
