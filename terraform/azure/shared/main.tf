# =========================================================================
# Azure Entra ID - SHARED (tenant-level, not per environment)
#
# Users, groups, memberships and SSO assignments are defined DIRECTLY as
# terraform resources in this file. (The previous users.json-driven
# approach has been removed.)
#
# Add new identity objects by uncommenting and adapting the examples below.
# =========================================================================

# --- Reference: existing Enterprise Application Service Principal ----------
# Uncomment when you need to assign a group/user to the SSO enterprise app.
#
# data "azuread_service_principal" "sso_app" {
#   client_id = var.enterprise_app_client_id
# }
#
# # AWS IAM Identity Center exposes two app roles ("User" and "msiam_access").
# # Pick "User" by display_name to avoid hardcoding the role GUID.
# locals {
#   sso_user_app_role_id = one([
#     for r in data.azuread_service_principal.sso_app.app_roles :
#     r.id if r.display_name == "User"
#   ])
# }

# --- Microsoft 365 (Unified) group: developers ----------------------------
# Unified group so it carries a mail attribute. mail_enabled = true is
# required for the 'Unified' type.
#
# IMPORTANT — the group's email domain:
#   On creation the mail lands on the tenant's default Exchange domain
#   (developers@<tenant>.onmicrosoft.com). Changing it to a custom domain
#   (developers@<custom-domain>) CANNOT be done through terraform, Microsoft
#   Graph, or the Azure CLI: Graph rejects writing group proxyAddresses for
#   ANY caller — app-only AND delegated admin tokens both get
#   "The requesting application is not authorized to set group proxy
#   addresses." The mail/PrimarySmtpAddress of a Microsoft 365 group is
#   Exchange-authoritative and can only be changed with Exchange Online
#   PowerShell, signed in as an Exchange admin:
#
#     Connect-ExchangeOnline -UserPrincipalName admin@<tenant>
#     Set-UnifiedGroup -Identity developers \
#       -PrimarySmtpAddress developers@<custom-domain>
#
#   The custom domain must be a verified, Exchange-enabled accepted domain
#   in the tenant. This is a manual step, outside terraform's lifecycle, and
#   must be re-applied if the group is destroyed and recreated.
#
#   Helper: terraform/azure/shared/set-group-email.sh wraps the command, e.g.
#     ./set-group-email.sh developers developers@<custom-domain>
resource "azuread_group" "developers" {
  display_name     = "developers"
  description      = "developers group (managed by terraform)"
  security_enabled = true
  mail_enabled     = true
  mail_nickname    = "developers"
  types            = ["Unified"]
}

# --- Microsoft 365 (Unified) group: datascientist -------------------------
# Same shape as the developers group above. On creation the mail lands on the
# tenant's default Exchange domain (datascientist@<tenant>.onmicrosoft.com);
# the custom-domain address datascientist@catatancloud.dev must be set AFTER
# apply with Exchange Online PowerShell (Graph/terraform cannot write it):
#
#   ./set-group-email.sh datascientist datascientist@catatancloud.dev admin@catatancloud.dev
resource "azuread_group" "datascientist" {
  display_name     = "datascientist"
  description      = "datascientist group (managed by terraform)"
  security_enabled = true
  mail_enabled     = true
  mail_nickname    = "datascientist"
  types            = ["Unified"]
}

# --- User: alice ----------------------------------------------------------
resource "random_password" "alice" {
  length           = 20
  special          = true
  override_special = "!@#$%^&*()-_=+"
}

resource "azuread_user" "alice" {
  user_principal_name   = "alice@catatancloud.dev"
  display_name          = "Alice Pratama"
  given_name            = "Alice"   # required for SCIM -> AWS
  surname               = "Pratama" # required for SCIM -> AWS
  mail_nickname         = "alice"
  password              = random_password.alice.result
  force_password_change = true
}

# alice is a member of the datascientist group.
resource "azuread_group_member" "alice_datascientist" {
  group_object_id  = azuread_group.datascientist.object_id
  member_object_id = azuread_user.alice.object_id
}

# --- Example: a user with a random initial password -----------------------
# resource "random_password" "example_user" {
#   length           = 20
#   special          = true
#   override_special = "!@#$%^&*()-_=+"
# }
#
# resource "azuread_user" "example_user" {
#   user_principal_name   = "user@example.com"
#   display_name          = "Example User"
#   given_name            = "Example"   # required for SCIM -> AWS
#   surname               = "User"      # required for SCIM -> AWS
#   mail_nickname         = "user"
#   password              = random_password.example_user.result
#   force_password_change = true
# }

# --- Example: group membership --------------------------------------------
# resource "azuread_group_member" "example_membership" {
#   group_object_id  = azuread_group.developers.object_id
#   member_object_id = azuread_user.example_user.object_id
# }

# --- Example: assign a group to the SSO enterprise app --------------------
# resource "azuread_app_role_assignment" "developers_to_sso" {
#   app_role_id         = local.sso_user_app_role_id
#   principal_object_id = azuread_group.developers.object_id
#   resource_object_id  = data.azuread_service_principal.sso_app.object_id
# }
