#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# set-group-email.sh — set the primary email (PrimarySmtpAddress) of a
# Microsoft 365 (Unified) group to a custom domain.
#
# Why this exists:
#   terraform's azuread_group can create a Unified group, but the group's
#   mail / PrimarySmtpAddress is Exchange-authoritative. Microsoft Graph
#   refuses to write group proxyAddresses for ANY caller (app-only AND
#   delegated admin), so the custom-domain email can only be set through
#   Exchange Online PowerShell. This script wraps that one command.
#
# Usage:
#   ./set-group-email.sh <group-name> <primary-email> [admin-upn]
#
#   <group-name>     display name / identity of the M365 group
#   <primary-email>  the address to make primary, e.g. team@yourdomain.tld
#                    (its domain must be a verified, Exchange-enabled
#                     accepted domain in the tenant)
#   [admin-upn]      optional Exchange/Global admin UPN to sign in as.
#                    May also be supplied via the EXO_ADMIN_UPN env var.
#                    If omitted, Connect-ExchangeOnline prompts interactively.
#
# A browser window opens for sign-in (interactive auth). The onmicrosoft.com
# address remains as a secondary alias — that is normal and unavoidable.
#
# Examples:
#   ./set-group-email.sh developers developers@yourdomain.tld
#   EXO_ADMIN_UPN=admin@yourdomain.tld ./set-group-email.sh ds ds@yourdomain.tld
# -----------------------------------------------------------------------------
set -euo pipefail

usage() {
  echo "Usage: $0 <group-name> <primary-email> [admin-upn]" >&2
  exit 1
}

[[ $# -ge 2 && $# -le 3 ]] || usage

GROUP="$1"
EMAIL="$2"
ADMIN="${3:-${EXO_ADMIN_UPN:-}}"

# Basic sanity check on the email shape.
if [[ ! "$EMAIL" =~ ^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$ ]]; then
  echo "ERR: '$EMAIL' does not look like a valid email address" >&2
  exit 1
fi

command -v pwsh >/dev/null 2>&1 || {
  echo "ERR: pwsh (PowerShell 7+) not found. Install with: brew install --cask powershell" >&2
  exit 1
}

echo ">> Target group : $GROUP"
echo ">> Primary email: $EMAIL"
[[ -n "$ADMIN" ]] && echo ">> Sign in as   : $ADMIN" || echo ">> Sign in as   : (interactive prompt)"
echo ">> A browser window will open for Exchange Online sign-in..."

# Pass values through the environment (no string interpolation into the
# PowerShell source — avoids any quoting/injection surprises).
GROUP="$GROUP" EMAIL="$EMAIL" ADMIN="$ADMIN" pwsh -NoProfile -Command '
  $ErrorActionPreference = "Stop"
  $g = $env:GROUP; $e = $env:EMAIL; $a = $env:ADMIN

  if (-not (Get-Module -ListAvailable ExchangeOnlineManagement)) {
    Write-Host ">> Installing ExchangeOnlineManagement module (CurrentUser)..."
    Install-Module ExchangeOnlineManagement -Scope CurrentUser -Force -AllowClobber
  }
  Import-Module ExchangeOnlineManagement

  if ([string]::IsNullOrWhiteSpace($a)) {
    Connect-ExchangeOnline -ShowBanner:$false
  } else {
    Connect-ExchangeOnline -UserPrincipalName $a -ShowBanner:$false
  }

  try {
    Set-UnifiedGroup -Identity $g -PrimarySmtpAddress $e
    Write-Host ""
    Write-Host ">> Updated. Current addresses:"
    Get-UnifiedGroup -Identity $g |
      Select-Object DisplayName, PrimarySmtpAddress, EmailAddresses |
      Format-List
  }
  finally {
    Disconnect-ExchangeOnline -Confirm:$false | Out-Null
  }
'

echo ">> Done. The Microsoft 365 admin centre / Azure AD 'mail' attribute may"
echo "   take a few minutes to reflect the new primary address."
