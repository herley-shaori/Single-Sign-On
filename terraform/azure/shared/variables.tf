variable "enterprise_app_client_id" {
  description = "Application (client) ID dari Enterprise Application target SSO assignment. Provider akan resolve ke Service Principal object_id."
  type        = string
}

variable "developers_group_name" {
  description = "Display name dari security group untuk developers"
  type        = string
  default     = "developers"
}

variable "user_upn" {
  description = "User Principal Name (UPN) untuk user yang dibuat"
  type        = string
}

variable "user_display_name" {
  description = "Display name user"
  type        = string
}

variable "user_mail_nickname" {
  description = "Mail nickname user (biasanya bagian sebelum @ dari UPN)"
  type        = string
}
