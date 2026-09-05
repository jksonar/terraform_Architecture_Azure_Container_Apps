#!/usr/bin/env bash
#
# build-images.sh
#
# Builds and pushes the django-todo and cosmos-crud container images from the
# local Django_todo_app/ and cosmos_crud/ directories in THIS repository (no
# git clone — both apps already live here) straight to the environment's ACR.
#
# The image tag is the current git commit SHA, so every pushed image is
# traceable back to the exact source that produced it:
#
#   Django_todo_app/  -> <acr>.azurecr.io/django-todo:<git-sha>
#   cosmos_crud/       -> <acr>.azurecr.io/cosmos-crud:<git-sha>
#
# Usage (from the repository root):
#   ./scripts/build-images.sh <environment>          # dev | staging | prod
#
# The ACR login server is read from that environment's `terraform output`
# (so `terraform apply` must have already succeeded there at least once).
# Override with ACR_LOGIN_SERVER to skip the terraform lookup entirely.
#
# On success, prints the two -var flags to feed straight into `terraform
# apply` (see scripts/deploy.sh, which does this for you end-to-end):
#
#   terraform apply \
#     -var="todo_container_image=<acr>.azurecr.io/django-todo:<sha>" \
#     -var="cosmos_crud_container_image=<acr>.azurecr.io/cosmos-crud:<sha>"
#
set -euo pipefail

ENVIRONMENT="${1:-}"
[[ -n "$ENVIRONMENT" ]] || { echo "Usage: $0 <environment>  (dev|staging|prod)" >&2; exit 1; }

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_DIR="${REPO_ROOT}/environments/${ENVIRONMENT}"
[[ -d "$ENV_DIR" ]] || { echo "error: no such environment directory: $ENV_DIR" >&2; exit 1; }

IMAGE_TAG="${IMAGE_TAG:-$(git -C "$REPO_ROOT" rev-parse --short HEAD)}"

log() { printf '\033[1;34m==>\033[0m %s\n' "$1"; }

if [[ -z "${ACR_LOGIN_SERVER:-}" ]]; then
  log "Reading ACR login server from terraform output in $ENV_DIR..."
  ACR_LOGIN_SERVER="$(cd "$ENV_DIR" && terraform output -raw container_registry_login_server 2>/dev/null)" \
    || { echo "error: couldn't read 'container_registry_login_server' output — has 'terraform apply' succeeded in $ENV_DIR?" >&2; exit 1; }
fi

TODO_IMAGE="${ACR_LOGIN_SERVER}/django-todo:${IMAGE_TAG}"
COSMOS_CRUD_IMAGE="${ACR_LOGIN_SERVER}/cosmos-crud:${IMAGE_TAG}"

log "ACR:        ${ACR_LOGIN_SERVER}"
log "Image tag:  ${IMAGE_TAG}"

log "Logging into ACR..."
az acr login --name "$(cut -d. -f1 <<<"$ACR_LOGIN_SERVER")"

log "Building django-todo (./Django_todo_app)..."
docker build --tag "$TODO_IMAGE" "${REPO_ROOT}/Django_todo_app"
log "Pushing ${TODO_IMAGE}"
docker push "$TODO_IMAGE"

log "Building cosmos-crud (./cosmos_crud)..."
docker build --tag "$COSMOS_CRUD_IMAGE" "${REPO_ROOT}/cosmos_crud"
log "Pushing ${COSMOS_CRUD_IMAGE}"
docker push "$COSMOS_CRUD_IMAGE"

echo
log "Images pushed successfully"
echo "TODO_IMAGE=${TODO_IMAGE}"
echo "COSMOS_CRUD_IMAGE=${COSMOS_CRUD_IMAGE}"
echo
echo "Next step — apply these to Terraform:"
echo "  cd environments/${ENVIRONMENT}"
echo "  terraform apply \\"
echo "    -var=\"todo_container_image=${TODO_IMAGE}\" \\"
echo "    -var=\"cosmos_crud_container_image=${COSMOS_CRUD_IMAGE}\""
