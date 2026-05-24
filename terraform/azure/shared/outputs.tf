output "managed_groups" {
  value = {
    for k, g in azuread_group.managed : k => g.object_id
  }
  description = "Map of managed group display_name -> object_id"
}

output "sso_app_display_name" {
  value       = data.azuread_service_principal.sso_app.display_name
  description = "Display name of the target SSO Enterprise Application"
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
  description = "Map of UPN -> user info for the users created by this stack"
}

output "user_initial_passwords" {
  value       = { for upn, p in random_password.user_initial : upn => p.result }
  sensitive   = true
  description = "Map of UPN -> initial password. Read all with: terraform output -json user_initial_passwords. Read one with: terraform output -json user_initial_passwords | jq -r '.\"<upn>\"'"
}
