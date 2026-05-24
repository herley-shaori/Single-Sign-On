# =========================================================================
# Azure Entra ID + Storage - environment: DEV
# =========================================================================
# Sample: Resource Group + Storage Account + Blob Container.
# Purpose: smoke-test that SP credentials (via ARM_* env vars) and the
# azurerm provider work end-to-end.
# =========================================================================

# Random suffix so the storage account name is globally unique.
resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
  numeric = true
}

resource "azurerm_resource_group" "sample" {
  name     = "rg-sso-${var.environment}-sample"
  location = "Southeast Asia"

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
    Project     = "sso"
    Purpose     = "smoke-test"
  }
}

resource "azurerm_storage_account" "sample" {
  name                     = "ssosample${var.environment}${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.sample.name
  location                 = azurerm_resource_group.sample.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"

  blob_properties {
    versioning_enabled = false
  }

  tags = azurerm_resource_group.sample.tags
}

resource "azurerm_storage_container" "sample" {
  name                  = "sample"
  storage_account_id    = azurerm_storage_account.sample.id
  container_access_type = "private"
}
