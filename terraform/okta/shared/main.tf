# =========================================================================
# Okta - SOURCE OF TRUTH (tenant-level, not per environment)
#
# Okta is the authoritative directory. Users and groups are defined here and
# provisioned OUTWARD to the downstream targets (AWS, GCP, Azure/Entra) via
# Okta's provisioning integrations (SCIM / app assignments). The downstream
# target modules (terraform/aws, terraform/gcp, terraform/azure) only consume
# these identities; they do not define them.
#
# Contract with targets (keep stable so a target never depends on Okta
# internals):
#   - AWS  keys off group NAME (the SCIM-provisioned group of the same name)
#   - GCP  keys off user EMAIL
#   - every user carries: login/email, first_name, last_name (required by SCIM)
#
# Add identity objects by uncommenting and adapting the examples below.
# =========================================================================

# --- Example: a user --------------------------------------------------------
# resource "okta_user" "example_user" {
#   first_name = "Example"          # required by SCIM -> downstream
#   last_name  = "User"             # required by SCIM -> downstream
#   login      = "user@example.com"
#   email      = "user@example.com"
#   # password omitted on purpose: invite/activation flows manage the secret.
# }

# --- Example: a group -------------------------------------------------------
# resource "okta_group" "developers" {
#   name        = "developers"
#   description = "developers group (managed by terraform)"
# }

# --- Example: group membership ----------------------------------------------
# resource "okta_group_memberships" "developers_members" {
#   group_id = okta_group.developers.id
#   users    = [okta_user.example_user.id]
# }

# --- Example: assign a group to a downstream provisioning app ----------------
# Each downstream cloud is represented in Okta by an application (e.g. the
# AWS / GCP / Azure SCIM apps). Assigning a group to that app is what puts its
# members in scope for provisioning to that cloud.
#
# resource "okta_app_group_assignment" "developers_to_aws" {
#   app_id   = var.aws_app_id    # the Okta app id for the AWS integration
#   group_id = okta_group.developers.id
# }
