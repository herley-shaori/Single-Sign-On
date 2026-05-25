# =========================================================================
# Azure Entra ID - SHARED (tenant-level, not per environment)
#
# User data is driven from users.json. To add or modify users, edit the
# JSON and run ./apply.sh azure shared from the terraform/ directory.
#
# Group data is currently held in local.managed_groups below. Add a new
# entry there to create a new security group (and have it auto-assigned to
# the SSO enterprise app).
# =========================================================================

# --- Reference: existing Enterprise Application Service Principal ----------
data "azuread_service_principal" "sso_app" {
  client_id = var.enterprise_app_client_id
}

# --- Managed groups -------------------------------------------------------
# Every group listed here is created in Azure AD AND assigned to the SSO
# enterprise application (so members get provisioned to AWS via SCIM).
#
# Groups are Microsoft 365 (Unified) groups with security_enabled = true:
#   - mail_enabled = true is required for the 'Unified' group type
#   - The resulting 'mail' attribute is <mail_nickname>@<initial-onmicrosoft-domain>
#     because catatancloud.dev is not configured as an Accepted Domain in
#     Exchange Online. To get the mail at @catatancloud.dev, that domain
#     must be added as an Accepted Domain first (Exchange admin action).
#   - The mail attribute is needed for GCP Cloud Identity SCIM sync, which
#     requires groups to have an email-format identifier.
locals {
  managed_groups = {
    developers      = { mail_nickname = "developers" }
    data_scientists = { mail_nickname = "ds" }
  }
}

resource "azuread_group" "managed" {
  for_each = local.managed_groups

  display_name     = each.key
  description      = "${each.key} group (managed by terraform)"
  security_enabled = true
  mail_enabled     = true
  mail_nickname    = each.value.mail_nickname
  types            = ["Unified"]
}

# --- Load user data from JSON ---------------------------------------------
locals {
  users_file = jsondecode(file("${path.module}/users.json"))
  users      = local.users_file.users

  # Map group display_name -> object_id, derived from azuread_group.managed.
  groups_by_name = {
    for k, g in azuread_group.managed : k => g.object_id
  }

  # Flatten (user, group) pairs into a stable map for for_each.
  # Key format: "<upn>|<group_name>"
  user_group_memberships = merge([
    for upn, u in local.users : {
      for g in u.group_memberships :
      "${upn}|${g}" => {
        upn   = upn
        group = g
      }
    }
  ]...)
}

# --- Initial password per user (random, sensitive) ------------------------
# Fetch with:
#   terraform output -json user_initial_passwords
resource "random_password" "user_initial" {
  for_each = local.users

  length           = 20
  special          = true
  override_special = "!@#$%^&*()-_=+"
}

# --- Users (driven from users.json) ---------------------------------------
resource "azuread_user" "users" {
  for_each = local.users

  user_principal_name   = each.key
  display_name          = each.value.display_name
  given_name            = each.value.given_name
  surname               = each.value.surname
  mail_nickname         = each.value.mail_nickname
  password              = random_password.user_initial[each.key].result
  force_password_change = true
}

# --- Group memberships (driven from users.json) ---------------------------
resource "azuread_group_member" "memberships" {
  for_each = local.user_group_memberships

  group_object_id  = local.groups_by_name[each.value.group]
  member_object_id = azuread_user.users[each.value.upn].object_id
}

# --- SSO assignment: every managed group -> Enterprise App ----------------
# Pick the app_role named "User" from the target SP (AWS IAM Identity
# Center exposes two roles: "User" and "msiam_access"). Looking up by
# display_name avoids hardcoding the role GUID.
locals {
  sso_user_app_role_id = one([
    for r in data.azuread_service_principal.sso_app.app_roles :
    r.id if r.display_name == "User"
  ])
}

resource "azuread_app_role_assignment" "groups_to_sso" {
  for_each = local.managed_groups

  app_role_id         = local.sso_user_app_role_id
  principal_object_id = azuread_group.managed[each.key].object_id
  resource_object_id  = data.azuread_service_principal.sso_app.object_id
}
