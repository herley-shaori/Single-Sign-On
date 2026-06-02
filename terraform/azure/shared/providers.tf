# =========================================================================
# Azure credentials are read from ENVIRONMENT VARIABLES:
#   - ARM_CLIENT_ID
#   - ARM_CLIENT_SECRET
#   - ARM_TENANT_ID
#   - ARM_SUBSCRIPTION_ID  (not strictly required for the azuread provider
#                            alone, but apply.sh validates all four vars)
#
# NEVER write secret values into .tf or .tfvars files.
# =========================================================================

provider "azuread" {}

provider "azurerm" {
  features {}
}
