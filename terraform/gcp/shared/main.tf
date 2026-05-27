# =========================================================================
# Google Workspace - SHARED (tenant-level, not per environment)
#
# Manages users in the Google Workspace tenant via the Directory API.
# Real provisioning requires the SA to have domain-wide delegation, plus
# var.impersonated_user_email pointing to a Workspace super admin.
# =========================================================================

# Random initial password for the user. Fetch with:
#   terraform output -raw user_initial_password
resource "random_password" "damian_initial" {
  length           = 16
  special          = true
  override_special = "!@#$%^&*()-_=+"
}

resource "googleworkspace_user" "damian" {
  primary_email = "damian@catatancloud.dev"

  name {
    given_name  = "Damian"
    family_name = "Davis"
  }

  password                      = random_password.damian_initial.result
  change_password_at_next_login = true
}
