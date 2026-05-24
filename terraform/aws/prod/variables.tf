variable "aws_region" {
  description = "AWS region where SSO resources are created"
  type        = string
}

variable "aws_profile" {
  description = "AWS CLI profile name (from ~/.aws/config) used for authentication"
  type        = string
}

variable "environment" {
  description = "Environment name (dev/prod)"
  type        = string
}
