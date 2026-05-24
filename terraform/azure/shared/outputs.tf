output "developers_group_object_id" {
  value       = azuread_group.developers.object_id
  description = "Object ID dari group developers"
}

output "user_object_id" {
  value       = azuread_user.herley.object_id
  description = "Object ID dari user yang dibuat"
}

output "user_principal_name" {
  value       = azuread_user.herley.user_principal_name
  description = "UPN user"
}

output "sso_app_display_name" {
  value       = data.azuread_service_principal.sso_app.display_name
  description = "Nama Enterprise Application target SSO"
}

output "user_initial_password" {
  value       = random_password.user_initial.result
  sensitive   = true
  description = "Password awal user. Ambil dengan: terraform output -raw user_initial_password"
}
