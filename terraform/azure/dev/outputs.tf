output "resource_group_name" {
  value       = azurerm_resource_group.sample.name
  description = "Name of the resource group created"
}

output "storage_account_name" {
  value       = azurerm_storage_account.sample.name
  description = "Storage account name (globally unique)"
}

output "storage_container_name" {
  value       = azurerm_storage_container.sample.name
  description = "Blob container name"
}

output "storage_account_primary_blob_endpoint" {
  value       = azurerm_storage_account.sample.primary_blob_endpoint
  description = "Primary blob endpoint URL"
}
