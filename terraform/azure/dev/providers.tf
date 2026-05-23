# =========================================================================
# Kredensial Azure dibaca dari ENVIRONMENT VARIABLES:
#   - ARM_CLIENT_ID
#   - ARM_CLIENT_SECRET
#   - ARM_TENANT_ID
#   - ARM_SUBSCRIPTION_ID
#
# JANGAN PERNAH menulis nilai rahasia (client_id / client_secret / tenant_id)
# di file .tf atau .tfvars. File ini hanya boleh memuat KONFIGURASI, bukan
# SECRET.
# =========================================================================

provider "azuread" {}

provider "azurerm" {
  features {}
}
