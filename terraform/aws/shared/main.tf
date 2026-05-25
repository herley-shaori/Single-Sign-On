# =========================================================================
# AWS IAM Identity Center (SSO) - SHARED (tenant-level, not per environment)
#
# Creates permission sets, attaches AWS-managed policies to them, and
# assigns each permission set to the relevant SCIM-provisioned group(s)
# in the target AWS account(s).
#
# To add a new permission set: append an entry to local.permission_sets.
# To target additional AWS accounts: set target_account_ids in tfvars.
# =========================================================================

# --- Discover IAM Identity Center instance & identity store ---------------
data "aws_ssoadmin_instances" "this" {}

data "aws_caller_identity" "current" {}

locals {
  sso_instance_arn  = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  identity_store_id = tolist(data.aws_ssoadmin_instances.this.identity_store_ids)[0]

  target_accounts = length(var.target_account_ids) > 0 ? var.target_account_ids : [data.aws_caller_identity.current.account_id]
}

# --- Permission sets configuration ----------------------------------------
# Each entry creates one aws_ssoadmin_permission_set plus the managed
# policy attachments, and assigns it to every listed group in every
# target account.
locals {
  permission_sets = {
    developers = {
      name                = "developers"
      description         = "EC2 full access for the developers group (managed by terraform)"
      session_duration    = "PT8H"
      managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonEC2FullAccess"]
      group_names         = ["developers"]
    }
    data_scientists = {
      name                = "data_scientists"
      description         = "S3 full access for the data_scientists group (managed by terraform)"
      session_duration    = "PT8H"
      managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonS3FullAccess"]
      group_names         = ["data_scientists"]
    }
  }

  # Unique set of all group display_names referenced anywhere above.
  all_group_names = toset(flatten([
    for ps in local.permission_sets : ps.group_names
  ]))

  # Cross product: permission_set x managed_policy_arn
  ps_policy_attachments = merge([
    for ps_key, ps in local.permission_sets : {
      for policy_arn in ps.managed_policy_arns :
      "${ps_key}|${policy_arn}" => {
        ps_key     = ps_key
        policy_arn = policy_arn
      }
    }
  ]...)

  # Cross product: permission_set x group x target_account
  ps_group_account_assignments = merge([
    for ps_key, ps in local.permission_sets : merge([
      for gname in ps.group_names : {
        for acct in local.target_accounts :
        "${ps_key}|${gname}|${acct}" => {
          ps_key     = ps_key
          group_name = gname
          account    = acct
        }
      }
    ]...)
  ]...)
}

# --- Look up each referenced group in the Identity Store ------------------
data "aws_identitystore_group" "by_name" {
  for_each = local.all_group_names

  identity_store_id = local.identity_store_id

  alternate_identifier {
    unique_attribute {
      attribute_path  = "DisplayName"
      attribute_value = each.key
    }
  }
}

# --- Permission sets ------------------------------------------------------
resource "aws_ssoadmin_permission_set" "this" {
  for_each = local.permission_sets

  instance_arn     = local.sso_instance_arn
  name             = each.value.name
  description      = each.value.description
  session_duration = each.value.session_duration
}

# --- Managed-policy attachments to permission sets ------------------------
resource "aws_ssoadmin_managed_policy_attachment" "this" {
  for_each = local.ps_policy_attachments

  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.this[each.value.ps_key].arn
  managed_policy_arn = each.value.policy_arn
}

# --- Account assignments: (permission_set, group, account) ----------------
resource "aws_ssoadmin_account_assignment" "this" {
  for_each = local.ps_group_account_assignments

  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.this[each.value.ps_key].arn

  principal_id   = data.aws_identitystore_group.by_name[each.value.group_name].group_id
  principal_type = "GROUP"

  target_id   = each.value.account
  target_type = "AWS_ACCOUNT"

  # The managed-policy attachment must exist before the assignment so the
  # permission set is fully formed when AWS provisions it into the target
  # account.
  depends_on = [aws_ssoadmin_managed_policy_attachment.this]
}

# --- Address migrations (rename of map keys) ------------------------------
# Permission set names were renamed to match the SCIM-provisioned group
# names. AWS treats the permission_set name as ForceNew, so each block
# below cleans up the state address; the resource itself is then replaced
# (destroy + recreate) by the plan because of the name change.
moved {
  from = aws_ssoadmin_permission_set.this["developers_ec2_full"]
  to   = aws_ssoadmin_permission_set.this["developers"]
}
moved {
  from = aws_ssoadmin_permission_set.this["data_scientists_s3_full"]
  to   = aws_ssoadmin_permission_set.this["data_scientists"]
}
moved {
  from = aws_ssoadmin_managed_policy_attachment.this["developers_ec2_full|arn:aws:iam::aws:policy/AmazonEC2FullAccess"]
  to   = aws_ssoadmin_managed_policy_attachment.this["developers|arn:aws:iam::aws:policy/AmazonEC2FullAccess"]
}
moved {
  from = aws_ssoadmin_managed_policy_attachment.this["data_scientists_s3_full|arn:aws:iam::aws:policy/AmazonS3FullAccess"]
  to   = aws_ssoadmin_managed_policy_attachment.this["data_scientists|arn:aws:iam::aws:policy/AmazonS3FullAccess"]
}
moved {
  from = aws_ssoadmin_account_assignment.this["developers_ec2_full|developers|623127157773"]
  to   = aws_ssoadmin_account_assignment.this["developers|developers|623127157773"]
}
moved {
  from = aws_ssoadmin_account_assignment.this["data_scientists_s3_full|data_scientists|623127157773"]
  to   = aws_ssoadmin_account_assignment.this["data_scientists|data_scientists|623127157773"]
}
