# -------------------------------------------------------------
# Elastic configuration
# -------------------------------------------------------------
variable "elastic_version" {
  type = string
  default = "8.5.3"
}

variable "elastic_region" {
  type = string
  default = "aws-eu-west-2"
}

variable "elastic_deployment_name" {
  type = string
  default = "AWS Workshop"
}

variable "elastic_deployment_template_id" {
  type = string
  default = "aws-general-purpose-arm-v5"
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
