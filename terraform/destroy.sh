#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Usage: ./destroy.sh <cloud> <env>
#   cloud : aws | azure
#   env   : dev | prod
#
# Untuk env=prod, kamu harus mengetik konfirmasi "destroy prod" sebelum jalan.
# -----------------------------------------------------------------------------
set -euo pipefail

usage() {
  echo "Usage: $0 <aws|azure> <dev|prod>" >&2
  exit 1
}

[[ $# -eq 2 ]] || usage

CLOUD="$1"
ENV="$2"

case "$CLOUD" in aws|azure) ;; *) echo "ERR: cloud harus 'aws' atau 'azure' (dapat '$CLOUD')" >&2; exit 1 ;; esac
case "$ENV"   in dev|prod)  ;; *) echo "ERR: env harus 'dev' atau 'prod' (dapat '$ENV')"   >&2; exit 1 ;; esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="$SCRIPT_DIR/$CLOUD/$ENV"

[[ -d "$TARGET_DIR" ]] || { echo "ERR: folder tidak ditemukan: $TARGET_DIR" >&2; exit 1; }

if [[ "$CLOUD" == "azure" ]]; then
  for v in ARM_CLIENT_ID ARM_CLIENT_SECRET ARM_TENANT_ID ARM_SUBSCRIPTION_ID; do
    [[ -n "${!v:-}" ]] || { echo "ERR: env var $v belum di-set" >&2; exit 1; }
  done
fi

# --- Konfirmasi extra untuk prod ---------------------------------------------
if [[ "$ENV" == "prod" ]]; then
  echo "!! Kamu mau DESTROY environment PROD ($CLOUD/$ENV) !!"
  read -r -p "   Ketik persis 'destroy prod' untuk lanjut: " confirm
  if [[ "$confirm" != "destroy prod" ]]; then
    echo "Dibatalkan."
    exit 1
  fi
fi

echo ">> [$CLOUD/$ENV] working dir: $TARGET_DIR"
cd "$TARGET_DIR"

echo ">> terraform init"
terraform init -input=false

echo ">> terraform destroy"
terraform destroy
