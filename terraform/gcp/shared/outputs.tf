output "developers_storage_admin_binding" {
  value       = google_project_iam_member.gcp_developers_storage_admin.id
  description = "Project-level IAM binding id granting the gcp-developers group roles/storage.admin"
}
