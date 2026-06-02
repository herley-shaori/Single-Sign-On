# =========================================================================
# GCP - SHARED (tenant-level, not per environment)
#
# Authorization only. Identities (users/groups) come from Okta (source of
# truth) provisioned into Google Workspace; this module does not create them.
# =========================================================================

# --- IAM: GCS full access for gcp-developers (project-level) --------------
# Project-level binding on var.gcp_project_id. (Org-level "all projects" is
# not available: this service account is project-scoped and the tenant has no
# GCP Organization, so the broadest achievable scope is this project.)
# The principal is the gcp-developers GROUP, provisioned into Google Workspace
# from Okta as gcp-developers@<domain>; members (alice) inherit the access.
resource "google_project_iam_member" "gcp_developers_storage_admin" {
  project = var.gcp_project_id
  role    = "roles/storage.admin"
  member  = "group:${var.gcp_developers_group_email}"
}
