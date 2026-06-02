variable "sa_credentials_file" {
  description = "File name (relative to this module) of the Google Workspace service account JSON. The file itself is git-ignored."
  type        = string
  default     = "sa.json"
}

variable "impersonated_user_email" {
  description = "Email of a Google Workspace super admin to impersonate. Required by the Directory API; the SA cannot operate alone."
  type        = string
}

variable "gcp_project_id" {
  description = "GCP project ID (used by the google provider as the default/quota project)."
  type        = string
}

variable "gcp_developers_group_email" {
  description = "Email of the Google group (provisioned from Okta as gcp-developers) to grant GCS access. Operator-specific, kept in git-ignored tfvars."
  type        = string
}
