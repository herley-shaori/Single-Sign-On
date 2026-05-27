# =========================================================================
# GCP / Google Workspace credentials are read from a service account JSON
# file local to this folder. The file is referenced by var.sa_credentials_file
# (default 'sa.json') and is git-ignored. NEVER commit the SA JSON.
#
# Workspace Directory API calls require the SA to use 'domain-wide
# delegation' and impersonate a Workspace super admin. The admin email is
# var.impersonated_user_email.
#
# customer_id = "my_customer" resolves to the Workspace customer that owns
# the impersonated user, so no hardcoded customer ID is needed.
# =========================================================================

provider "googleworkspace" {
  credentials             = file("${path.module}/${var.sa_credentials_file}")
  customer_id             = "my_customer"
  impersonated_user_email = var.impersonated_user_email

  oauth_scopes = [
    "https://www.googleapis.com/auth/admin.directory.user",
  ]
}
