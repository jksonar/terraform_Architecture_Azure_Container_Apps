# Canonical backend template — copied into each environments/<env>/backend.tf
# with only the `key` (state file path) changed, so dev/staging/prod each get
# their own state file in the same remote backend.
#
# Prereq: a storage account for Terraform state must exist before first init
# (create it once via `az group create` / `az storage account create`, or a
# small bootstrap config — not part of this project since it can't manage the
# state store it depends on).
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-tfstate"
    storage_account_name = "sttfstateshared" # must be globally unique; override to your own
    container_name       = "tfstate"
    key                  = "azure-container-apps/CHANGE_ME.terraform.tfstate"
  }
}
