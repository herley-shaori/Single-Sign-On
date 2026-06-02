# =========================================================================
# GCP - SHARED (tenant-level, not per environment)
#
# Authorization only. Identities (users/groups) come from Okta (source of
# truth) provisioned into Google Workspace; this module does not create them.
# =========================================================================

# --- IAM: GCS full access for gcp-developers across ALL projects ----------
# Organization-level binding => inherited by EVERY project in the org, i.e.
# "all projects". The principal is the gcp-developers GROUP, which is
# provisioned into Google Workspace from Okta as gcp-developers@<domain>;
# members (alice) inherit the access. The binding is inert until that Google
# group actually exists.
#
# Prerequisites for apply:
#   - a GCP Organization (var.gcp_org_id), and
#   - the service account holding Organization-level IAM permission
#     (e.g. roles/resourcemanager.organizationAdmin or a custom role that can
#     set org IAM policy).
resource "google_organization_iam_member" "gcp_developers_storage_admin" {
  org_id = var.gcp_org_id
  role   = "roles/storage.admin"
  member = "group:${var.gcp_developers_group_email}"
}
