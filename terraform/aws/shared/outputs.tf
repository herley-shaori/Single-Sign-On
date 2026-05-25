output "sso_instance_arn" {
  value       = local.sso_instance_arn
  description = "ARN of the discovered IAM Identity Center instance"
}

output "identity_store_id" {
  value       = local.identity_store_id
  description = "ID of the discovered Identity Store"
}

output "target_accounts" {
  value       = local.target_accounts
  description = "AWS account IDs that received permission-set assignments"
}

output "permission_sets" {
  value = {
    for k, ps in aws_ssoadmin_permission_set.this : k => {
      name = ps.name
      arn  = ps.arn
    }
  }
  description = "Map of internal key -> permission set name and ARN"
}

# TEMPORARILY COMMENTED OUT while the data.aws_identitystore_group is
# commented out in main.tf (see note there).
#
# output "groups" {
#   value = {
#     for name, g in data.aws_identitystore_group.by_name : name => g.group_id
#   }
#   description = "Map of group display_name -> Identity Store group_id (as resolved from SCIM-provisioned groups)"
# }
