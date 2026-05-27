output "user_id" {
  value       = googleworkspace_user.damian.id
  description = "Google Workspace user ID"
}

output "user_primary_email" {
  value       = googleworkspace_user.damian.primary_email
  description = "Primary email of the user"
}

output "user_initial_password" {
  value       = random_password.damian_initial.result
  sensitive   = true
  description = "Initial password. Read with: terraform output -raw user_initial_password"
}
