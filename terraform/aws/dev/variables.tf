variable "aws_region" {
  description = "AWS region tempat resource SSO dibuat"
  type        = string
}

variable "aws_profile" {
  description = "Nama AWS CLI profile (dari ~/.aws/config) yang dipakai untuk auth"
  type        = string
}

variable "environment" {
  description = "Nama environment (dev/prod)"
  type        = string
}
