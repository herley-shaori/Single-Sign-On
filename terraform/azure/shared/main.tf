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
# required for the 'Unified' type. The mail domain is assigned by the tenant
# from an Exchange-enabled domain; to land on a custom domain that domain
# must be an Exchange Online accepted domain.
resource "azuread_group" "developers" {
  display_name     = "developers"
  description      = "developers group (managed by terraform)"
  security_enabled = true
  mail_enabled     = true
  mail_nickname    = "developers"
  types            = ["Unified"]
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
