# =========================================================================
# Azure Entra ID - SHARED (tenant-level, not per environment)
#
# Users, groups, memberships and provisioning assignments are defined
# DIRECTLY as terraform resources in this file. (The previous users.json-
# driven approach has been removed.)
#
# Add new identity objects by uncommenting and adapting the examples below.
# =========================================================================

# --- Reference: SSO enterprise application (AWS IAM Identity Center) -------
# Uncomment when assigning a group/user to the AWS SSO app. Groups must be
# ASSIGNED to this app to be provisioned via SCIM; an unassigned group is
# skipped with SkipReason=NotEffectivelyEntitled.
#
# data "azuread_service_principal" "sso_app" {
#   client_id = var.enterprise_app_client_id
# }
#
# # AWS IAM Identity Center exposes app roles "User" and "msiam_access".
# # Pick "User" by display_name to avoid hardcoding the role GUID.
# locals {
#   sso_user_app_role_id = one([
#     for r in data.azuread_service_principal.sso_app.app_roles :
#     r.id if r.display_name == "User"
#   ])
# }

# --- Reference: Google Cloud / G Suite Connector by Microsoft -------------
# Uncomment when assigning a group to the Google Workspace provisioning app.
#
# data "azuread_service_principal" "gcp_app" {
#   client_id = var.gcp_provisioning_app_client_id
# }
#
# # The Google connector exposes app roles "msiam_access" (internal SSO
# # metadata) and "Default Organization". Provisioning assignments use
# # "Default Organization"; pick it by display_name to avoid a hardcoded GUID.
# locals {
#   gcp_app_role_id = one([
#     for r in data.azuread_service_principal.gcp_app.app_roles :
#     r.id if r.display_name == "Default Organization"
#   ])
# }

# --- Example: Microsoft 365 (Unified) group -------------------------------
# Unified group so it carries a mail attribute. mail_enabled = true and
# types = ["Unified"] are required for the Unified type.
#
# IMPORTANT — the group's email domain:
#   On creation the mail lands on the tenant's default Exchange domain
#   (<nickname>@<tenant>.onmicrosoft.com). Changing it to a custom domain
#   CANNOT be done through terraform, Microsoft Graph, or the Azure CLI:
#   Graph rejects writing group proxyAddresses for ANY caller. The
#   mail/PrimarySmtpAddress of a Microsoft 365 group is Exchange-
#   authoritative and can only be changed with Exchange Online PowerShell,
#   signed in as an Exchange admin. This is a manual step, outside
#   terraform's lifecycle, and must be re-applied if the group is destroyed
#   and recreated. Helper: terraform/azure/shared/set-group-email.sh, e.g.
#     ./set-group-email.sh <group> <group>@<custom-domain> <admin-upn>
#
# resource "azuread_group" "example_group" {
#   display_name     = "example"
#   description      = "example group (managed by terraform)"
#   security_enabled = true
#   mail_enabled     = true
#   mail_nickname    = "example"
#   types            = ["Unified"]
# }

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
#   group_object_id  = azuread_group.example_group.object_id
#   member_object_id = azuread_user.example_user.object_id
# }

# --- Example: assign a group to the AWS SSO enterprise app ----------------
# Without this assignment the group is skipped by SCIM provisioning
# (SkipReason=NotEffectivelyEntitled).
#
# resource "azuread_app_role_assignment" "example_to_sso" {
#   app_role_id         = local.sso_user_app_role_id
#   principal_object_id = azuread_group.example_group.object_id
#   resource_object_id  = data.azuread_service_principal.sso_app.object_id
# }

# --- Example: assign a group to the Google Workspace connector ------------
# resource "azuread_app_role_assignment" "example_to_gcp" {
#   app_role_id         = local.gcp_app_role_id
#   principal_object_id = azuread_group.example_group.object_id
#   resource_object_id  = data.azuread_service_principal.gcp_app.object_id
# }
