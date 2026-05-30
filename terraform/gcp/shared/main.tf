# =========================================================================
# Google Workspace + GCP - SHARED (tenant-level, not per environment)
#
# Manages Workspace users + GCP project-level IAM bindings for them.
# Users are intended to come from SCIM sync going forward; only Damian is
# explicitly managed here because he was provisioned before SCIM was
# wired up.
# =========================================================================

# --- IAM: 'developers' role mapping (project-level) -----------------------
# Members of the 'developers' role get full Cloud Storage access on the
# target project. Bind at project level here; switch to organization-level
# binding once a GCP Organization exists for your domain and the SA has
# Organization IAM Admin permission.
#
# Emails are passed via var.developers_emails (tfvars-local, never tracked).
# They must exist as Google identities (Workspace users or otherwise)
# before the binding actually grants access. For SCIM-provisioned users,
# the email is created on the Workspace side first; this binding then
# references them by email and activates automatically.

resource "google_project_iam_member" "developers_storage_admin" {
  for_each = toset(var.developers_emails)

  project = var.gcp_project_id
  role    = "roles/storage.admin"
  member  = "user:${each.key}"
}
