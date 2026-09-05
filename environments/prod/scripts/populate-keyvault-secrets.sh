#!/usr/bin/env bash
#
# populate-keyvault-secrets.sh
#
# Run this AFTER `terraform apply` has succeeded in this same environment
# directory (environments/dev, environments/staging, or environments/prod —
# this script is identical in all three; only the terraform state it reads
# differs). It:
#
#   1. Reads the PostgreSQL Flexible Server connection details, Key Vault
#      name, Container App name/identity, etc. straight out of
#      `terraform output` (no values are hand-typed).
#   2. Writes the Django_todo_app settings as secrets into that
#      environment's Key Vault via `az keyvault secret set`.
#   3. Wires each Key Vault secret into the Container App as an environment
#      variable, using the Container App's native Key Vault secret
#      reference (`keyvaultref:...,identityref:...`) — the app's managed
#      identity already holds "Key Vault Secrets User" on the vault (granted
#      in main.tf), so no secret value is ever duplicated in the Container
#      App spec itself.
#
# SECRET_KEY is generated once and only once: re-running this script will
# NOT rotate it (that would invalidate every active Django session). All
# other values (DB host/user/password/etc.) are re-synced from Terraform's
# current state on every run, so re-run this after any `terraform apply`
# that changes the database (e.g. a password rotation).
#
# IMPORTANT: `terraform apply` declaratively sets the Container App's env var
# list (currently COSMOS_DB_ENDPOINT / KEY_VAULT_URI, in main.tf's
# `containerapps` module block) and will overwrite whatever this script
# wires in via `az containerapp update --set-env-vars` on its NEXT run. This
# script must therefore be re-run once after every `terraform apply` that
# touches the container app, to restore the Key Vault secret references.
#
# Usage (from inside environments/<env>/, after `terraform apply`):
#   ./scripts/populate-keyvault-secrets.sh [options]
#
# Options (all can also be set via environment variables of the same name):
#   --django-env dev|uat|prod   Which Django_todo_app settings module/.env this
#                                maps to. Default: guessed from the directory
#                                name (dev->dev, staging->uat, prod->prod).
#   --allowed-hosts HOSTS        Comma-separated ALLOWED_HOSTS value. Default:
#                                the environment's Application Gateway public
#                                IP plus localhost/127.0.0.1.
#   --email-host HOST            Only meaningful for --django-env prod.
#   --email-port PORT            (SMTP creds aren't derivable from Azure infra —
#   --email-user USER             pass them explicitly or set them later with
#   --email-password PASSWORD     `az keyvault secret set`.)
#   -h, --help                   Show this help and exit
#
set -euo pipefail

DJANGO_ENV="${DJANGO_ENV:-}"
ALLOWED_HOSTS="${ALLOWED_HOSTS:-}"
EMAIL_HOST="${EMAIL_HOST:-}"
EMAIL_PORT="${EMAIL_PORT:-587}"
EMAIL_USE_TLS="${EMAIL_USE_TLS:-True}"
EMAIL_HOST_USER="${EMAIL_HOST_USER:-}"
EMAIL_HOST_PASSWORD="${EMAIL_HOST_PASSWORD:-}"

usage() {
  sed -n '2,/^set -euo pipefail/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --django-env) DJANGO_ENV="$2"; shift 2 ;;
    --allowed-hosts) ALLOWED_HOSTS="$2"; shift 2 ;;
    --email-host) EMAIL_HOST="$2"; shift 2 ;;
    --email-port) EMAIL_PORT="$2"; shift 2 ;;
    --email-user) EMAIL_HOST_USER="$2"; shift 2 ;;
    --email-password) EMAIL_HOST_PASSWORD="$2"; shift 2 ;;
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

command -v az >/dev/null 2>&1 || die "Azure CLI ('az') is not installed."
command -v terraform >/dev/null 2>&1 || die "Terraform is not installed."
az account show >/dev/null 2>&1 || die "Not logged in to Azure CLI. Run 'az login' first."

az extension show --name containerapp >/dev/null 2>&1 || {
  log "Installing the 'containerapp' az cli extension..."
  az extension add --name containerapp --only-show-errors >/dev/null
}

[[ -f "./outputs.tf" ]] || die "Run this from inside environments/<env>/ (no outputs.tf found in $(pwd))."

# ---------------------------------------------------------------------------
# Pull everything we need out of Terraform state
# ---------------------------------------------------------------------------

log "Reading terraform outputs from $(pwd)..."
tf_out() { terraform output -raw "$1" 2>/dev/null || die "Missing terraform output '$1' — did 'terraform apply' finish successfully in $(pwd)?"; }

KEY_VAULT_NAME="$(tf_out key_vault_name)"
KEY_VAULT_URI="$(tf_out key_vault_uri)"
RESOURCE_GROUP="$(tf_out resource_group_name)"
CONTAINER_APP_NAME="$(tf_out container_app_name)"
IDENTITY_ID="$(tf_out container_app_managed_identity_id)"
APPGW_PUBLIC_IP="$(tf_out application_gateway_public_ip)"
PG_HOST="$(tf_out postgresql_fqdn)"
PG_DB="$(tf_out postgresql_database_name)"
PG_USER="$(tf_out postgresql_administrator_login)"
PG_PASSWORD="$(tf_out postgresql_administrator_password)"

if [[ -z "$DJANGO_ENV" ]]; then
  case "$(basename "$(pwd)")" in
    dev)     DJANGO_ENV="dev" ;;
    staging) DJANGO_ENV="uat" ;;   # this terraform environment is Django_todo_app's UAT
    prod)    DJANGO_ENV="prod" ;;
    *) die "Can't guess --django-env from directory '$(basename "$(pwd)")'. Pass --django-env dev|uat|prod explicitly." ;;
  esac
fi
case "$DJANGO_ENV" in
  dev|uat|prod) ;;
  *) die "--django-env must be one of: dev, uat, prod (got '$DJANGO_ENV')" ;;
esac

if [[ -z "$ALLOWED_HOSTS" ]]; then
  ALLOWED_HOSTS="${APPGW_PUBLIC_IP},localhost,127.0.0.1"
  warn "No --allowed-hosts given; defaulting to '${ALLOWED_HOSTS}'. Add your real domain once one is configured on the Application Gateway."
fi

log "Key Vault             : $KEY_VAULT_NAME"
log "Container App         : $CONTAINER_APP_NAME (rg: $RESOURCE_GROUP)"
log "Django settings module: taskmanager.settings.${DJANGO_ENV}"
log "Postgres host         : $PG_HOST"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# az keyvault secret names allow only letters/numbers/dashes (no underscores).
kv_set() {
  local name="$1" value="$2"
  az keyvault secret set --vault-name "$KEY_VAULT_NAME" --name "$name" --value "$value" --output none
}

kv_exists() {
  az keyvault secret show --vault-name "$KEY_VAULT_NAME" --name "$1" >/dev/null 2>&1
}

# ---------------------------------------------------------------------------
# Django core settings
# ---------------------------------------------------------------------------

if kv_exists "django-secret-key"; then
  log "django-secret-key already exists in Key Vault — leaving it as-is (rotating it would invalidate active sessions)."
else
  log "Generating SECRET_KEY (first run for this vault)..."
  SECRET_KEY="$(python3 -c 'import secrets; print(secrets.token_urlsafe(50))' 2>/dev/null || openssl rand -base64 50 | tr -d '\n')"
  kv_set "django-secret-key" "$SECRET_KEY"
fi

DEBUG_VALUE="False"
[[ "$DJANGO_ENV" == "dev" ]] && DEBUG_VALUE="True"

log "Writing Django core secrets..."
kv_set "django-debug" "$DEBUG_VALUE"
kv_set "django-allowed-hosts" "$ALLOWED_HOSTS"
kv_set "django-settings-module" "taskmanager.settings.${DJANGO_ENV}"

log "Writing PostgreSQL connection secrets..."
kv_set "postgres-db" "$PG_DB"
kv_set "postgres-user" "$PG_USER"
kv_set "postgres-password" "$PG_PASSWORD"
kv_set "postgres-host" "$PG_HOST"
kv_set "postgres-port" "5432"

# SMTP creds aren't derivable from Azure infra - only write them if given.
if [[ "$DJANGO_ENV" == "prod" ]]; then
  if [[ -n "$EMAIL_HOST" ]]; then
    log "Writing email secrets..."
    kv_set "email-host" "$EMAIL_HOST"
    kv_set "email-port" "$EMAIL_PORT"
    kv_set "email-use-tls" "$EMAIL_USE_TLS"
    kv_set "email-host-user" "$EMAIL_HOST_USER"
    kv_set "email-host-password" "$EMAIL_HOST_PASSWORD"
  else
    warn "No --email-host given; skipping email-* secrets. Set them later with 'az keyvault secret set --vault-name $KEY_VAULT_NAME --name email-host-password --value ...' (and email-host/email-port/email-use-tls/email-host-user) before relying on EMAIL_BACKEND in prod."
  fi
fi

# ---------------------------------------------------------------------------
# Wire each Key Vault secret into the Container App
# ---------------------------------------------------------------------------

# kv-secret-name:ENV_VAR_NAME pairs. The Container App secret name reuses the
# Key Vault secret name (both allow lowercase letters/numbers/dashes).
declare -a MAPPINGS=(
  "django-secret-key:SECRET_KEY"
  "django-debug:DEBUG"
  "django-allowed-hosts:ALLOWED_HOSTS"
  "django-settings-module:DJANGO_SETTINGS_MODULE"
  "postgres-db:POSTGRES_DB"
  "postgres-user:POSTGRES_USER"
  "postgres-password:POSTGRES_PASSWORD"
  "postgres-host:DB_HOST"
  "postgres-port:DB_PORT"
)
if [[ "$DJANGO_ENV" == "prod" && -n "$EMAIL_HOST" ]]; then
  MAPPINGS+=(
    "email-host:EMAIL_HOST"
    "email-port:EMAIL_PORT"
    "email-use-tls:EMAIL_USE_TLS"
    "email-host-user:EMAIL_HOST_USER"
    "email-host-password:EMAIL_HOST_PASSWORD"
  )
fi

log "Registering Container App secrets (Key Vault references)..."
SECRET_ARGS=()
ENV_VAR_ARGS=()
for mapping in "${MAPPINGS[@]}"; do
  kv_name="${mapping%%:*}"
  env_name="${mapping##*:}"
  SECRET_ARGS+=("${kv_name}=keyvaultref:${KEY_VAULT_URI}secrets/${kv_name},identityref:${IDENTITY_ID}")
  ENV_VAR_ARGS+=("${env_name}=secretref:${kv_name}")
done

az containerapp secret set \
  --name "$CONTAINER_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --secrets "${SECRET_ARGS[@]}" \
  --output none

log "Updating Container App environment variables (this creates a new revision)..."
az containerapp update \
  --name "$CONTAINER_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --set-env-vars "${ENV_VAR_ARGS[@]}" \
  --output none

log "Done. Django_todo_app's Container App now pulls its DB/Django settings from Key Vault '$KEY_VAULT_NAME'."
