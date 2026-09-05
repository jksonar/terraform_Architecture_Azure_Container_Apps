#!/usr/bin/env bash
#
# deploy.sh
#
# End-to-end deploy for one environment: infra first (with whatever image is
# already in tfvars/state — the public hello-world placeholder on a first
# run), then build+push the real images, then a second apply to roll them
# out. This avoids the chicken-and-egg problem of the Container Apps needing
# an image that can't exist until the ACR they're created alongside does.
#
#   terraform apply (infra + placeholder/previous image)
#           |
#           v
#   scripts/build-images.sh (docker build + push, from local dirs)
#           |
#           v
#   terraform apply -var=todo_container_image=... -var=cosmos_crud_container_image=...
#
# Usage (from the repository root):
#   ./scripts/deploy.sh <environment>          # dev | staging | prod
#
# By default both `terraform apply` runs are interactive (Terraform's normal
# plan + yes/no prompt). Set AUTO_APPROVE=true to pass -auto-approve to both.
#
set -euo pipefail

ENVIRONMENT="${1:-}"
[[ -n "$ENVIRONMENT" ]] || { echo "Usage: $0 <environment>  (dev|staging|prod)" >&2; exit 1; }

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_DIR="${REPO_ROOT}/environments/${ENVIRONMENT}"
[[ -d "$ENV_DIR" ]] || { echo "error: no such environment directory: $ENV_DIR" >&2; exit 1; }

AUTO_APPROVE="${AUTO_APPROVE:-false}"
APPLY_ARGS=(-var-file=terraform.tfvars)
[[ "$AUTO_APPROVE" == "true" ]] && APPLY_ARGS+=(-auto-approve)

log() { printf '\033[1;34m==>\033[0m %s\n' "$1"; }

log "Step 1/3 — terraform apply (infrastructure)"
(cd "$ENV_DIR" && terraform init -input=false && terraform apply "${APPLY_ARGS[@]}")

log "Step 2/3 — build and push images"
BUILD_OUTPUT="$("${REPO_ROOT}/scripts/build-images.sh" "$ENVIRONMENT")"
echo "$BUILD_OUTPUT"
TODO_IMAGE="$(grep '^TODO_IMAGE=' <<<"$BUILD_OUTPUT" | cut -d= -f2-)"
COSMOS_CRUD_IMAGE="$(grep '^COSMOS_CRUD_IMAGE=' <<<"$BUILD_OUTPUT" | cut -d= -f2-)"

log "Step 3/3 — terraform apply (roll out new images)"
(cd "$ENV_DIR" && terraform apply "${APPLY_ARGS[@]}" \
  -var="todo_container_image=${TODO_IMAGE}" \
  -var="cosmos_crud_container_image=${COSMOS_CRUD_IMAGE}")

log "Done. ${ENVIRONMENT} is live behind $(cd "$ENV_DIR" && terraform output -raw application_gateway_public_ip)"
