#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Usage: ./apply.sh <cloud> <env>
#   cloud : aws | azure
#   env   : dev | prod | shared
#
# 'shared' dipakai untuk resource tenant-level yang tidak per-environment
# (contoh: azure/shared untuk group/user/SSO assignment yang dipakai di
# semua environment).
#
# Contoh:
#   ./apply.sh aws   dev
#   ./apply.sh azure prod
#   ./apply.sh azure shared
# -----------------------------------------------------------------------------
set -euo pipefail

usage() {
  echo "Usage: $0 <aws|azure> <dev|prod|shared>" >&2
  exit 1
}

[[ $# -eq 2 ]] || usage

CLOUD="$1"
ENV="$2"

case "$CLOUD" in aws|azure)       ;; *) echo "ERR: cloud harus 'aws' atau 'azure' (dapat '$CLOUD')"        >&2; exit 1 ;; esac
case "$ENV"   in dev|prod|shared) ;; *) echo "ERR: env harus 'dev', 'prod', atau 'shared' (dapat '$ENV')" >&2; exit 1 ;; esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="$SCRIPT_DIR/$CLOUD/$ENV"

[[ -d "$TARGET_DIR" ]] || { echo "ERR: folder tidak ditemukan: $TARGET_DIR" >&2; exit 1; }

# --- Guard: Azure butuh ARM_* env vars ---------------------------------------
if [[ "$CLOUD" == "azure" ]]; then
  missing=()
  for v in ARM_CLIENT_ID ARM_CLIENT_SECRET ARM_TENANT_ID ARM_SUBSCRIPTION_ID; do
    [[ -n "${!v:-}" ]] || missing+=("$v")
  done
  if (( ${#missing[@]} > 0 )); then
    cat >&2 <<EOF
ERR: env var Azure berikut belum di-set: ${missing[*]}

Set dulu di shell-mu (JANGAN simpan ke file yang di-commit):
  export ARM_CLIENT_ID="<appId>"
  export ARM_CLIENT_SECRET="<password>"
  export ARM_TENANT_ID="<tenant>"
  export ARM_SUBSCRIPTION_ID="<subscription-id>"
EOF
    exit 1
  fi
fi

echo ">> [$CLOUD/$ENV] working dir: $TARGET_DIR"
cd "$TARGET_DIR"

echo ">> terraform init"
terraform init -input=false

echo ">> terraform validate"
terraform validate

echo ">> terraform plan"
terraform plan -input=false -out=tfplan

echo ">> terraform apply"
terraform apply -input=false -auto-approve tfplan

rm -f tfplan
echo ">> done."
