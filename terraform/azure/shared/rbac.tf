# =========================================================================
# Azure RBAC - blob storage full access for the azure-developers group
#
# alice gets full blob-data access via the azure-developers GROUP, which is
# provisioned into Entra ID from Okta (source of truth). Assigning the group
# (not the person) keeps Okta authoritative for membership.
#
# Role "Storage Blob Data Owner" = full data-plane access to blob (read/
# write/delete + manage POSIX ACLs). Scope is the whole subscription so it
# applies across all storage accounts; narrow to a resource group or storage
# account id for tighter scope.
#
# Inert/blocked until the azure-developers group exists in Entra (provisioned
# from Okta); the data source resolves its object id by display name.
# =========================================================================

data "azurerm_subscription" "current" {}

data "azuread_group" "azure_developers" {
  display_name = "azure-developers"
}

resource "azurerm_role_assignment" "azure_developers_blob" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = data.azuread_group.azure_developers.object_id
}
