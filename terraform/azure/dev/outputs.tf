output "resource_group_name" {
  value       = azurerm_resource_group.sample.name
  description = "Nama resource group yang dibuat"
}

output "storage_account_name" {
  value       = azurerm_storage_account.sample.name
  description = "Nama storage account (globally unique)"
}

output "storage_container_name" {
  value       = azurerm_storage_container.sample.name
  description = "Nama blob container"
}

output "storage_account_primary_blob_endpoint" {
  value       = azurerm_storage_account.sample.primary_blob_endpoint
  description = "Endpoint blob primary"
}
