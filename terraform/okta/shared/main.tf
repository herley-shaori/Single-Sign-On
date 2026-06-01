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

# --- Group: aws-developers -------------------------------------------------
# Okta groups carry only name + description (no email attribute). The NAME is
# the contract key downstream (e.g. AWS matches the SCIM group by this name).
# Cloud-prefixed so each target gets its own group (this one is for AWS; on
# the Google side the analogous group would be aws-developers@catatancloud.dev).
resource "okta_group" "aws_developers" {
  name        = "aws-developers"
  description = "AWS developers group (managed by terraform; source of truth)"
}

# --- User: alice -----------------------------------------------------------
resource "okta_user" "alice" {
  first_name = "Alice"   # required by SCIM -> downstream
  last_name  = "Pratama" # required by SCIM -> downstream
  login      = "alice@catatancloud.dev"
  email      = "alice@catatancloud.dev"
}

# alice is a member of the aws-developers group.
resource "okta_group_memberships" "aws_developers_members" {
  group_id = okta_group.aws_developers.id
  users    = [okta_user.alice.id]
}

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
