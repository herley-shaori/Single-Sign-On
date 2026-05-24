#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Usage: ./apply.sh <cloud> <env>
#   cloud : aws | azure
#   env   : dev | prod | shared
#
# 'shared' is used for tenant-level resources that are not per environment
# (e.g. azure/shared for the group/user/SSO assignments shared across envs).
#
# Examples:
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

case "$CLOUD" in aws|azure)       ;; *) echo "ERR: cloud must be 'aws' or 'azure' (got '$CLOUD')"          >&2; exit 1 ;; esac
case "$ENV"   in dev|prod|shared) ;; *) echo "ERR: env must be 'dev', 'prod', or 'shared' (got '$ENV')"   >&2; exit 1 ;; esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="$SCRIPT_DIR/$CLOUD/$ENV"

[[ -d "$TARGET_DIR" ]] || { echo "ERR: folder not found: $TARGET_DIR" >&2; exit 1; }

# --- Guard: Azure requires ARM_* env vars ------------------------------------
if [[ "$CLOUD" == "azure" ]]; then
  missing=()
  for v in ARM_CLIENT_ID ARM_CLIENT_SECRET ARM_TENANT_ID ARM_SUBSCRIPTION_ID; do
    [[ -n "${!v:-}" ]] || missing+=("$v")
  done
  if (( ${#missing[@]} > 0 )); then
    cat >&2 <<EOF
ERR: the following Azure env vars are not set: ${missing[*]}

Set them in your shell (DO NOT save them to a tracked file):
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
