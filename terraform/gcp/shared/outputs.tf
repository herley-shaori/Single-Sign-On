output "developers_iam_members" {
  value = {
    for k, m in google_project_iam_member.developers_storage_admin :
    k => m.id
  }
  description = "Map of developer email -> IAM member binding ID (project-level)"
}
