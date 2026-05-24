# =========================================================================
# Azure credentials are read from ENVIRONMENT VARIABLES:
#   - ARM_CLIENT_ID
#   - ARM_CLIENT_SECRET
#   - ARM_TENANT_ID
#   - ARM_SUBSCRIPTION_ID
#
# NEVER write secret values (client_id / client_secret / tenant_id) into
# .tf or .tfvars files. Those files must only hold CONFIGURATION, never
# SECRETS.
# =========================================================================

provider "azuread" {}

provider "azurerm" {
  features {}
}
