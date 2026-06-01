# =========================================================================
# Okta is the SOURCE OF TRUTH for users and groups. This provider talks to
# the Okta management API using an OAuth 2.0 service app with the
# private_key_jwt grant (no static API token).
#
# Credentials:
#   - org_name / base_url / client_id : non-secret identifiers, supplied via
#     terraform.tfvars (git-ignored) — see terraform.tfvars.example.
#   - private_key : the RSA private key whose PUBLIC half is registered on the
#     Okta service app. Read from a local PEM file (var.okta_private_key_file,
#     default 'okta_api_key.pem') that is git-ignored by multiple patterns.
#     NEVER commit the PEM, and never inline the key into a .tf/.tfvars file.
#
# The Okta org may enforce DPoP (sender-constrained tokens) on the service
# app; the provider must be a version that supports DPoP, otherwise disable
# the "Require DPoP" setting on the app. The required API scopes
# (var.okta_scopes) must be granted to the service app in the Okta Admin
# console (Applications -> the app -> Okta API Scopes) or token requests fail
# with "consent_required".
# =========================================================================

provider "okta" {
  org_name  = var.okta_org_name
  base_url  = var.okta_base_url
  client_id = var.okta_client_id
  scopes    = var.okta_scopes

  private_key    = file("${path.module}/${var.okta_private_key_file}")
  private_key_id = var.okta_private_key_id
}
