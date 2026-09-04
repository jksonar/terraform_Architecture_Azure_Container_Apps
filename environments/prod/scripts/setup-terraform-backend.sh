#!/usr/bin/env bash
#
# setup-terraform-backend.sh
#
# Bootstraps the Azure storage account used as the shared remote backend for
# this project's Terraform state. Run this ONCE per subscription before
# `terraform init`. It is safe to re-run (idempotent): every other developer
# on the team can run the same script with the same defaults and it will
# just detect the existing resources and (re)generate their local backend.tf.
#
# What it creates, in a resource group SEPARATE from the app resources
# managed by this repo's .tf files:
#   - Resource group     (default: rg-terraform-state)
#   - Storage account     (default: sttfstate<8-char hash of subscription id>)
#       StorageV2, Standard_LRS, TLS1.2 minimum, HTTPS-only, public blob
#       access disabled, blob versioning + soft delete enabled.
#   - Blob container      (default: tfstate)
#
# Access is via Azure AD (no storage account keys are created or stored):
# the script grants the current signed-in user the "Storage Blob Data
# Contributor" role on the storage account, and the generated backend.tf
# uses use_azuread_auth = true. Additional developers need the same role
# assigned on the storage account (this script grants it to whoever runs
# it; an admin can grant it to teammates the same way, or via
# `az role assignment create`).
#
# State locking is handled automatically by the azurerm backend via blob
# leases - no extra configuration needed.
#
# Usage:
#   ./setup-terraform-backend.sh [options]
#
# Options (all can also be set via environment variables of the same name):
#   -g, --resource-group NAME     Resource group for backend state (default: rg-terraform-state)
#   -l, --location LOCATION       Azure region (default: eastus)
#   -a, --storage-account NAME    Storage account name (default: derived from subscription id)
#   -c, --container NAME          Blob container name (default: tfstate)
#   -k, --key NAME                State file (blob) name (default: terraform.tfstate)
#   -s, --subscription ID_OR_NAME Azure subscription to use (default: az cli current subscription)
#       --skip-role-assignment    Do not attempt to grant yourself the Storage Blob Data Contributor role
#   -h, --help                    Show this help and exit
#

# What it does:

# Creates a separate resource group (default rg-terraform-state) and storage account (default sttfstate<hash-of-subscription-id>, so the name is deterministic per subscription — every developer who runs it lands on the same account).
# Hardens the storage account: TLS 1.2 minimum, HTTPS-only, public blob access disabled, shared-key access disabled, blob versioning + 30-day soft delete.
# Uses Azure AD auth only (no storage keys generated/stored) and grants the current user Storage Blob Data Contributor on the account.
# Creates the tfstate blob container, then writes a backend.tf in the repo with the azurerm backend block (use_azuread_auth = true) so a plain terraform init picks it up.
# Fully idempotent — safe to re-run, and other developers just run the same script to get a backend.tf pointing at the same shared state store (an admin then grants them the RBAC role if they lack it).
# Usage:


# ./setup-terraform-backend.sh
# terraform init
# Override any name via flags (-g/--resource-group, -a/--storage-account, -c/--container, -l/--location, -k/--key) or matching env vars — see ./setup-terraform-backend.sh --help.

set -euo pipefail

# ---------------------------------------------------------------------------
# Defaults / argument parsing
# ---------------------------------------------------------------------------

RESOURCE_GROUP="${RESOURCE_GROUP:-rg-terraform-state-prod}"
LOCATION="${LOCATION:-eastus}"
STORAGE_ACCOUNT="${STORAGE_ACCOUNT:-}"
CONTAINER_NAME="${CONTAINER_NAME:-tfstate}"
STATE_KEY="${STATE_KEY:-terraform.tfstate}"
SUBSCRIPTION="${SUBSCRIPTION:-}"
SKIP_ROLE_ASSIGNMENT="${SKIP_ROLE_ASSIGNMENT:-false}"
BACKEND_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/backend.tf"

usage() {
  sed -n '2,/^set -euo pipefail/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -g|--resource-group) RESOURCE_GROUP="$2"; shift 2 ;;
    -l|--location) LOCATION="$2"; shift 2 ;;
    -a|--storage-account) STORAGE_ACCOUNT="$2"; shift 2 ;;
    -c|--container) CONTAINER_NAME="$2"; shift 2 ;;
    -k|--key) STATE_KEY="$2"; shift 2 ;;
    -s|--subscription) SUBSCRIPTION="$2"; shift 2 ;;
    --skip-role-assignment) SKIP_ROLE_ASSIGNMENT="true"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

log()  { printf '\033[1;34m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m warning:\033[0m %s\n' "$1" >&2; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$1" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Preflight
# ---------------------------------------------------------------------------

command -v az >/dev/null 2>&1 || die "Azure CLI ('az') is not installed. Install it first: https://learn.microsoft.com/cli/azure/install-azure-cli"

az account show >/dev/null 2>&1 || die "Not logged in to Azure CLI. Run 'az login' first."

if [[ -n "$SUBSCRIPTION" ]]; then
  log "Selecting subscription: $SUBSCRIPTION"
  az account set --subscription "$SUBSCRIPTION"
fi

SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
SUBSCRIPTION_NAME="$(az account show --query name -o tsv)"
log "Using subscription: $SUBSCRIPTION_NAME ($SUBSCRIPTION_ID)"

if [[ -z "$STORAGE_ACCOUNT" ]]; then
  SUFFIX="$(echo -n "$SUBSCRIPTION_ID" | sha1sum | cut -c1-8)"
  STORAGE_ACCOUNT="sttfstate${SUFFIX}"
fi

if ! [[ "$STORAGE_ACCOUNT" =~ ^[a-z0-9]{3,24}$ ]]; then
  die "Storage account name '$STORAGE_ACCOUNT' is invalid: must be 3-24 lowercase letters/numbers."
fi

log "Backend resource group : $RESOURCE_GROUP"
log "Backend location       : $LOCATION"
log "Backend storage account: $STORAGE_ACCOUNT"
log "Backend container      : $CONTAINER_NAME"
log "State key (blob name)  : $STATE_KEY"

# ---------------------------------------------------------------------------
# Resource group (idempotent)
# ---------------------------------------------------------------------------

if az group show --name "$RESOURCE_GROUP" >/dev/null 2>&1; then
  log "Resource group '$RESOURCE_GROUP' already exists, reusing it."
else
  log "Creating resource group '$RESOURCE_GROUP' in $LOCATION..."
  az group create --name "$RESOURCE_GROUP" --location "$LOCATION" >/dev/null
fi

# ---------------------------------------------------------------------------
# Storage account (idempotent)
# ---------------------------------------------------------------------------

if az storage account show --name "$STORAGE_ACCOUNT" --resource-group "$RESOURCE_GROUP" >/dev/null 2>&1; then
  log "Storage account '$STORAGE_ACCOUNT' already exists, reusing it."
else
  # Storage account names are globally unique across all of Azure - fail
  # loudly and clearly if someone else already took this name elsewhere.
  if [[ "$(az storage account check-name --name "$STORAGE_ACCOUNT" --query nameAvailable -o tsv)" != "true" ]]; then
    die "Storage account name '$STORAGE_ACCOUNT' is already taken in another subscription/tenant. Pass --storage-account with a different name."
  fi

  log "Creating storage account '$STORAGE_ACCOUNT'..."
  az storage account create \
    --name "$STORAGE_ACCOUNT" \
    --resource-group "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --sku Standard_LRS \
    --kind StorageV2 \
    --min-tls-version TLS1_2 \
    --https-only true \
    --allow-blob-public-access false \
    --allow-shared-key-access false \
    >/dev/null
fi

STORAGE_ACCOUNT_ID="$(az storage account show --name "$STORAGE_ACCOUNT" --resource-group "$RESOURCE_GROUP" --query id -o tsv)"

log "Enabling blob versioning and soft delete..."
az storage account blob-service-properties update \
  --account-name "$STORAGE_ACCOUNT" \
  --resource-group "$RESOURCE_GROUP" \
  --enable-versioning true \
  --enable-delete-retention true \
  --delete-retention-days 30 \
  >/dev/null

# ---------------------------------------------------------------------------
# Grant the current user access to the state data (Azure AD auth, no keys)
# ---------------------------------------------------------------------------

if [[ "$SKIP_ROLE_ASSIGNMENT" != "true" ]]; then
  CURRENT_USER_OBJECT_ID="$(az ad signed-in-user show --query id -o tsv 2>/dev/null || true)"
  if [[ -n "$CURRENT_USER_OBJECT_ID" ]]; then
    log "Granting 'Storage Blob Data Contributor' on the storage account to the current user..."
    if az role assignment list --assignee "$CURRENT_USER_OBJECT_ID" --scope "$STORAGE_ACCOUNT_ID" --role "Storage Blob Data Contributor" -o tsv | grep -q .; then
      log "Role already assigned."
    else
      az role assignment create \
        --assignee-object-id "$CURRENT_USER_OBJECT_ID" \
        --assignee-principal-type User \
        --role "Storage Blob Data Contributor" \
        --scope "$STORAGE_ACCOUNT_ID" \
        >/dev/null
      log "Role assigned. Note: Azure AD role assignments can take a minute or two to propagate."
    fi
  else
    warn "Could not resolve the signed-in user (are you using a service principal?). Skipping role assignment - make sure the identity running Terraform has 'Storage Blob Data Contributor' on $STORAGE_ACCOUNT."
  fi
fi

# ---------------------------------------------------------------------------
# Blob container (idempotent), using Azure AD auth
# ---------------------------------------------------------------------------

log "Creating blob container '$CONTAINER_NAME' (this may retry briefly while the role assignment propagates)..."
for attempt in $(seq 1 10); do
  if az storage container show \
      --name "$CONTAINER_NAME" \
      --account-name "$STORAGE_ACCOUNT" \
      --auth-mode login \
      >/dev/null 2>&1; then
    log "Container already exists, reusing it."
    break
  fi
  if az storage container create \
      --name "$CONTAINER_NAME" \
      --account-name "$STORAGE_ACCOUNT" \
      --auth-mode login \
      --output none 2>/dev/null; then
    log "Container created."
    break
  fi
  if [[ "$attempt" -eq 10 ]]; then
    die "Failed to create container '$CONTAINER_NAME' after $attempt attempts. Re-run this script once the role assignment has propagated."
  fi
  sleep 10
done

# ---------------------------------------------------------------------------
# Write backend.tf for `terraform init`
# ---------------------------------------------------------------------------

log "Writing $BACKEND_FILE"
cat > "$BACKEND_FILE" <<EOF
# Generated by setup-terraform-backend.sh - shared remote state backend.
# Do not edit the values below by hand; re-run setup-terraform-backend.sh
# with the same options instead so every developer stays in sync.
terraform {
  backend "azurerm" {
    resource_group_name  = "${RESOURCE_GROUP}"
    storage_account_name = "${STORAGE_ACCOUNT}"
    container_name        = "${CONTAINER_NAME}"
    key                    = "${STATE_KEY}"
    use_azuread_auth       = true
  }
}
EOF

log "Done."
echo
echo "Backend ready:"
echo "  resource group : $RESOURCE_GROUP"
echo "  storage account: $STORAGE_ACCOUNT"
echo "  container       : $CONTAINER_NAME"
echo "  key             : $STATE_KEY"
echo
echo "Next steps:"
echo "  terraform init"
echo
echo "Other developers: run this same script (defaults are deterministic per"
echo "subscription) to have their backend.tf generated pointing at the same"
echo "storage account, then have an admin grant them the 'Storage Blob Data"
echo "Contributor' role on $STORAGE_ACCOUNT if they don't already have it."
