#!/usr/bin/env bash
#
# bootstrap-acr.sh
#
# There is intentionally nothing to do here. The Azure Container Registry is
# created directly by Terraform (module.containerregistry, wired into
# environments/<env>/main.tf) — no separate pre-Terraform bootstrap step is
# needed. The ordering problem this script's name implies ("ACR must exist
# before the Container App, but the Container App's image must exist before
# the Container App") is solved differently: `todo_container_image` /
# `cosmos_crud_container_image` default to a public placeholder image, so the
# first `terraform apply` succeeds and creates the ACR; scripts/build-images.sh
# then builds the real images straight into that ACR, and a second
# `terraform apply` rolls them out. See scripts/deploy.sh for the combined
# flow.
#
# This file is kept as a documented no-op rather than removed, since it's
# referenced by name in the project's architecture notes (Plan.md).
set -euo pipefail
echo "Nothing to bootstrap — the ACR is created by 'terraform apply' itself." >&2
echo "Run scripts/deploy.sh <environment> for the full apply -> build -> apply flow." >&2
