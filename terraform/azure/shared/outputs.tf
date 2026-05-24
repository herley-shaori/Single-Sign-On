output "developers_group_object_id" {
  value       = azuread_group.developers.object_id
  description = "Object ID dari group developers"
}

output "sso_app_display_name" {
  value       = data.azuread_service_principal.sso_app.display_name
  description = "Nama Enterprise Application target SSO"
}

output "users" {
  value = {
    for upn, u in azuread_user.users : upn => {
      object_id    = u.object_id
      display_name = u.display_name
      given_name   = u.given_name
      surname      = u.surname
    }
  }
  description = "Map UPN -> info user yang dibuat"
}

output "user_initial_passwords" {
  value       = { for upn, p in random_password.user_initial : upn => p.result }
  sensitive   = true
  description = "Map UPN -> initial password. Ambil semua: terraform output -json user_initial_passwords. Ambil satu: terraform output -json user_initial_passwords | jq -r '.\"<upn>\"'"
}
