data "azurerm_client_config" "current" {}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

locals {
  name = "${var.prefix}-${var.environment}-${random_string.suffix.result}"
  tags = merge(var.tags, {
    environment = var.environment
    managed_by  = "terraform"
  })
}

resource "azurerm_resource_group" "this" {
  name     = "rg-${local.name}"
  location = var.location
  tags     = local.tags
}

module "monitoring" {
  source = "../../modules/monitoring"

  name                = "log-${local.name}"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  retention_in_days   = var.log_analytics_retention_days
  tags                = local.tags
}

module "network" {
  source = "../../modules/network"

  name                            = "vnet-${local.name}"
  resource_group_name             = azurerm_resource_group.this.name
  location                        = azurerm_resource_group.this.location
  address_space                   = var.vnet_address_space
  appgw_subnet_prefix             = var.appgw_subnet_prefix
  container_apps_subnet_prefix    = var.container_apps_subnet_prefix
  private_endpoints_subnet_prefix = var.private_endpoints_subnet_prefix
  tags                            = local.tags
}

module "nsg" {
  source = "../../modules/nsg"

  name_prefix                 = local.name
  resource_group_name         = azurerm_resource_group.this.name
  location                    = azurerm_resource_group.this.location
  appgw_subnet_id             = module.network.appgw_subnet_id
  appgw_subnet_prefix         = var.appgw_subnet_prefix
  container_apps_subnet_id    = module.network.container_apps_subnet_id
  private_endpoints_subnet_id = module.network.private_endpoints_subnet_id
  tags                        = local.tags
}

module "keyvault" {
  source = "../../modules/keyvault"

  name                = substr("kv-${local.name}", 0, 24)
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = var.key_vault_sku
  tags                = local.tags
}

module "containerregistry" {
  source = "../../modules/containerregistry"

  name                = substr(replace("acr${local.name}", "/[^a-zA-Z0-9]/", ""), 0, 50)
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  sku                 = var.acr_sku
  tags                = local.tags
}

module "database" {
  source = "../../modules/database"

  name                = "cosmos-${local.name}"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  offer_type          = var.cosmosdb_offer_type
  consistency_level   = var.cosmosdb_consistency_level
  database_name       = var.cosmosdb_database_name
  container_name      = var.cosmosdb_container_name
  partition_key_path  = var.cosmosdb_partition_key_path
  tags                = local.tags
}

module "privateendpoints" {
  source = "../../modules/privateendpoints"

  name_prefix           = local.name
  resource_group_name   = azurerm_resource_group.this.name
  location              = azurerm_resource_group.this.location
  vnet_id               = module.network.vnet_id
  subnet_id             = module.network.private_endpoints_subnet_id
  container_registry_id = module.containerregistry.id
  key_vault_id          = module.keyvault.id
  cosmosdb_account_id   = module.database.id
  tags                  = local.tags
}

# User-assigned identity the Container App runs as. Created at root (not in
# the containerapps module) so the role assignments below — which need its
# principal_id — and the module's own depends_on can both reference it
# without a circular module dependency.
resource "azurerm_user_assigned_identity" "container_app" {
  name                = "id-containerapp-${local.name}"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  tags                = local.tags
}

resource "azurerm_role_assignment" "acr_pull" {
  scope                = module.containerregistry.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.container_app.principal_id
}

resource "azurerm_role_assignment" "kv_secrets_user" {
  scope                = module.keyvault.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.container_app.principal_id
}

resource "azurerm_role_assignment" "kv_admin_deployer" {
  scope                = module.keyvault.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Built-in "Cosmos DB Built-in Data Contributor" role — control-plane RBAC
# alone does not grant Cosmos DB data-plane access.
resource "azurerm_cosmosdb_sql_role_assignment" "container_app" {
  resource_group_name = azurerm_resource_group.this.name
  account_name        = module.database.name
  role_definition_id  = "${module.database.id}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002"
  principal_id        = azurerm_user_assigned_identity.container_app.principal_id
  scope               = module.database.id
}

module "containerapps" {
  source = "../../modules/containerapps"

  name_prefix                = local.name
  resource_group_name        = azurerm_resource_group.this.name
  location                   = azurerm_resource_group.this.location
  log_analytics_workspace_id = module.monitoring.id
  infrastructure_subnet_id   = module.network.container_apps_subnet_id
  workload_profile_enabled   = var.container_app_environment_workload_profile
  vnet_id                    = module.network.vnet_id
  identity_id                = azurerm_user_assigned_identity.container_app.id
  identity_client_id         = azurerm_user_assigned_identity.container_app.client_id
  registry_login_server      = module.containerregistry.login_server
  container_image            = var.container_image
  target_port                = var.container_app_target_port
  cpu                        = var.container_cpu
  memory                     = var.container_memory
  min_replicas               = var.container_app_min_replicas
  max_replicas               = var.container_app_max_replicas
  tags                       = local.tags

  env_vars = {
    COSMOS_DB_ENDPOINT = module.database.endpoint
    KEY_VAULT_URI      = module.keyvault.vault_uri
  }

  depends_on = [
    azurerm_role_assignment.acr_pull,
    azurerm_role_assignment.kv_secrets_user,
    azurerm_cosmosdb_sql_role_assignment.container_app,
  ]
}

module "appgateway" {
  source = "../../modules/appgateway"

  name_prefix         = local.name
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  subnet_id           = module.network.appgw_subnet_id
  backend_fqdn        = module.containerapps.app_ingress_fqdn
  enable_waf          = var.enable_waf
  min_capacity        = var.appgw_min_capacity
  max_capacity        = var.appgw_max_capacity
  tags                = local.tags

  # The environment's private DNS zone/records (created inside the
  # containerapps module) must exist before the gateway's FQDN-based backend
  # pool can resolve them.
  depends_on = [module.containerapps]
}
