# =========================================================================
# GCP / Google Workspace credentials are read from a service account JSON
# file local to this folder. The file is referenced by var.sa_credentials_file
# (default 'sa.json') and is git-ignored. NEVER commit the SA JSON.
#
# Two providers, both authed by the same SA file:
#   - googleworkspace: Workspace Directory API (user/group). Needs domain-
#     wide delegation + var.impersonated_user_email (a Workspace super
#     admin).
#   - google: GCP organization / project APIs (IAM bindings, etc.). The SA
#     itself needs the relevant org/project IAM roles to operate.
# =========================================================================

provider "googleworkspace" {
  credentials             = file("${path.module}/${var.sa_credentials_file}")
  customer_id             = "my_customer"
  impersonated_user_email = var.impersonated_user_email

  oauth_scopes = [
    "https://www.googleapis.com/auth/admin.directory.user",
  ]
}

provider "google" {
  credentials = file("${path.module}/${var.sa_credentials_file}")
}
