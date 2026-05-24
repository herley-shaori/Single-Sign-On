# =========================================================================
# Azure Entra ID - SHARED (tenant-level, bukan per-environment)
#
# Mengelola:
#   - security group "developers"
#   - user Herley Al-Ash
#   - membership user -> group
#   - assignment group -> Enterprise Application (SSO)
# =========================================================================

# --- Reference: existing Enterprise Application Service Principal ----------
data "azuread_service_principal" "sso_app" {
  client_id = var.enterprise_app_client_id
}

# --- Security group: developers --------------------------------------------
resource "azuread_group" "developers" {
  display_name     = var.developers_group_name
  description      = "Developers security group (managed by terraform)"
  security_enabled = true
  mail_enabled     = false
}

# --- Initial password (random) ---------------------------------------------
# Di-output sebagai sensitive value. Ambil dengan:
#   terraform output -raw user_initial_password
resource "random_password" "user_initial" {
  length           = 20
  special          = true
  override_special = "!@#$%^&*()-_=+"
}

# --- User: Herley Al-Ash ---------------------------------------------------
resource "azuread_user" "herley" {
  user_principal_name   = var.user_upn
  display_name          = var.user_display_name
  mail_nickname         = var.user_mail_nickname
  password              = random_password.user_initial.result
  force_password_change = true
}

# --- Membership: herley -> developers --------------------------------------
resource "azuread_group_member" "herley_in_developers" {
  group_object_id  = azuread_group.developers.object_id
  member_object_id = azuread_user.herley.object_id
}

# --- SSO assignment: developers group -> Enterprise App --------------------
# Pilih app_role "User" yang sudah ada di SP target (AWS IAM Identity Center
# punya 2 roles: "User" dan "msiam_access"). Pakai display_name supaya tidak
# hardcode GUID — kalau SP punya role bernama lain, ganti filter-nya.
locals {
  sso_user_app_role_id = one([
    for r in data.azuread_service_principal.sso_app.app_roles :
    r.id if r.display_name == "User"
  ])
}

resource "azuread_app_role_assignment" "developers_to_sso" {
  app_role_id         = local.sso_user_app_role_id
  principal_object_id = azuread_group.developers.object_id
  resource_object_id  = data.azuread_service_principal.sso_app.object_id
}
