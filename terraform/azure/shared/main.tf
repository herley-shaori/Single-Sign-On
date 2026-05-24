# =========================================================================
# Azure Entra ID - SHARED (tenant-level, bukan per-environment)
#
# User-data di-drive dari users.json. Untuk tambah/ubah user, edit JSON,
# lalu jalan ./apply.sh azure shared dari folder terraform/.
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

# --- Load user data from JSON ----------------------------------------------
locals {
  users_file = jsondecode(file("${path.module}/users.json"))
  users      = local.users_file.users

  # Map nama group -> object_id (untuk dipakai oleh memberships).
  # Tambah entry di sini kalau bikin azuread_group baru di atas.
  groups_by_name = {
    developers = azuread_group.developers.object_id
  }

  # Flatten (user, group) pairs jadi map yang stable buat for_each.
  # Key: "<upn>|<group_name>"
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

# --- Initial password per user (random, sensitive) -------------------------
# Output: terraform output -json user_initial_passwords
resource "random_password" "user_initial" {
  for_each = local.users

  length           = 20
  special          = true
  override_special = "!@#$%^&*()-_=+"
}

# --- Users (driven from users.json) ----------------------------------------
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

# --- Group memberships (driven from users.json) ----------------------------
resource "azuread_group_member" "memberships" {
  for_each = local.user_group_memberships

  group_object_id  = local.groups_by_name[each.value.group]
  member_object_id = azuread_user.users[each.value.upn].object_id
}

# --- SSO assignment: developers group -> Enterprise App --------------------
# Pilih app_role bernama "User" dari SP target (AWS IAM Identity Center
# punya 2 roles: "User" dan "msiam_access"). Pakai display_name supaya
# tidak hardcode GUID.
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
