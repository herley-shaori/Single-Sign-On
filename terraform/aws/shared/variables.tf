variable "aws_region" {
  description = "AWS region used by the provider (IAM Identity Center API calls)"
  type        = string
}

variable "aws_profile" {
  description = "AWS CLI profile name (from ~/.aws/config) used for authentication"
  type        = string
}

variable "target_account_ids" {
  description = "AWS account IDs to assign permission sets to. If empty, the account behind aws_profile is used."
  type        = list(string)
  default     = []
}
