#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Usage: ./destroy.sh <cloud> <env>
#   cloud : aws | azure
#   env   : dev | prod | shared
#
# When env=prod, the operator must type the literal string "destroy prod"
# to confirm before the destroy runs.
# -----------------------------------------------------------------------------
set -euo pipefail

usage() {
  echo "Usage: $0 <aws|azure> <dev|prod|shared>" >&2
  exit 1
}

[[ $# -eq 2 ]] || usage

CLOUD="$1"
ENV="$2"

case "$CLOUD" in aws|azure)       ;; *) echo "ERR: cloud must be 'aws' or 'azure' (got '$CLOUD')"        >&2; exit 1 ;; esac
case "$ENV"   in dev|prod|shared) ;; *) echo "ERR: env must be 'dev', 'prod', or 'shared' (got '$ENV')" >&2; exit 1 ;; esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="$SCRIPT_DIR/$CLOUD/$ENV"

[[ -d "$TARGET_DIR" ]] || { echo "ERR: folder not found: $TARGET_DIR" >&2; exit 1; }

if [[ "$CLOUD" == "azure" ]]; then
  for v in ARM_CLIENT_ID ARM_CLIENT_SECRET ARM_TENANT_ID ARM_SUBSCRIPTION_ID; do
    [[ -n "${!v:-}" ]] || { echo "ERR: env var $v is not set" >&2; exit 1; }
  done
fi

# --- Extra confirmation for prod ---------------------------------------------
if [[ "$ENV" == "prod" ]]; then
  echo "!! About to DESTROY production ($CLOUD/$ENV) !!"
  read -r -p "   Type exactly 'destroy prod' to continue: " confirm
  if [[ "$confirm" != "destroy prod" ]]; then
    echo "Aborted."
    exit 1
  fi
fi

echo ">> [$CLOUD/$ENV] working dir: $TARGET_DIR"
cd "$TARGET_DIR"

echo ">> terraform init"
terraform init -input=false

echo ">> terraform destroy"
terraform destroy
