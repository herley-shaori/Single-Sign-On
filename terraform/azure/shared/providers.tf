# =========================================================================
# Kredensial Azure dibaca dari ENVIRONMENT VARIABLES:
#   - ARM_CLIENT_ID
#   - ARM_CLIENT_SECRET
#   - ARM_TENANT_ID
#   - ARM_SUBSCRIPTION_ID  (tidak strictly diperlukan untuk azuread saja,
#                            tapi script apply.sh memvalidasi semua 4 vars)
#
# JANGAN PERNAH menulis nilai rahasia di file .tf / .tfvars.
# =========================================================================

provider "azuread" {}
