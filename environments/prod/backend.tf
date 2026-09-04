terraform {
  backend "azurerm" {
    resource_group_name  = "rg-tfstate"
    storage_account_name = "sttfstateshared" # must be globally unique; override to your own
    container_name       = "tfstate"
    key                  = "azure-container-apps/prod.terraform.tfstate"
  }
}
