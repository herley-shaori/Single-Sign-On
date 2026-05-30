output "user_id" {
  value       = googleworkspace_user.damian.id
  description = "Google Workspace user ID for Damian"
}

output "user_primary_email" {
  value       = googleworkspace_user.damian.primary_email
  description = "Primary email of Damian"
}

output "user_initial_password" {
  value       = random_password.damian_initial.result
  sensitive   = true
  description = "Initial password. Read with: terraform output -raw user_initial_password"
}

output "developers_iam_members" {
  value = {
    for k, m in google_project_iam_member.developers_storage_admin :
    k => m.id
  }
  description = "Map of developer email -> IAM member binding ID (project-level)"
}
