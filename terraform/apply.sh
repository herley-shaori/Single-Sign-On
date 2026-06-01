#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Usage: ./apply.sh <cloud> <env>
#   cloud : aws | azure | gcp | okta
#   env   : dev | prod | shared
#
# 'shared' is used for tenant-level resources that are not per environment
# (e.g. okta/shared, the source of truth for users/groups).
#
# Examples:
#   ./apply.sh aws   dev
#   ./apply.sh azure prod
#   ./apply.sh azure shared
#   ./apply.sh gcp   shared
#   ./apply.sh okta  shared
# -----------------------------------------------------------------------------
set -euo pipefail

usage() {
  echo "Usage: $0 <aws|azure|gcp|okta> <dev|prod|shared>" >&2
  exit 1
}

[[ $# -eq 2 ]] || usage

CLOUD="$1"
ENV="$2"

case "$CLOUD" in aws|azure|gcp|okta) ;; *) echo "ERR: cloud must be 'aws', 'azure', 'gcp', or 'okta' (got '$CLOUD')" >&2; exit 1 ;; esac
case "$ENV"   in dev|prod|shared)    ;; *) echo "ERR: env must be 'dev', 'prod', or 'shared' (got '$ENV')"  >&2; exit 1 ;; esac

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

# --- Guard: GCP needs the service account JSON file in the target dir --------
if [[ "$CLOUD" == "gcp" ]]; then
  if [[ ! -f "$TARGET_DIR/sa.json" ]]; then
    echo "ERR: GCP service account file not found at $TARGET_DIR/sa.json" >&2
    echo "     Place the JSON there (the file is git-ignored)."          >&2
    exit 1
  fi
fi

# --- Guard: Okta needs the private-key PEM file in the target dir -------------
if [[ "$CLOUD" == "okta" ]]; then
  if [[ ! -f "$TARGET_DIR/okta_api_key.pem" ]]; then
    echo "ERR: Okta API private key not found at $TARGET_DIR/okta_api_key.pem" >&2
    echo "     Place the PEM (PKCS#8) there (the file is git-ignored)."        >&2
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
