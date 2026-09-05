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
  postgresql_subnet_prefix        = var.postgresql_subnet_prefix
  tags                            = local.tags
}

module "nsg" {
  source = "../../modules/nsg"

  name_prefix                  = local.name
  resource_group_name          = azurerm_resource_group.this.name
  location                     = azurerm_resource_group.this.location
  appgw_subnet_id              = module.network.appgw_subnet_id
  appgw_subnet_prefix          = var.appgw_subnet_prefix
  container_apps_subnet_id     = module.network.container_apps_subnet_id
  container_apps_subnet_prefix = var.container_apps_subnet_prefix
  private_endpoints_subnet_id  = module.network.private_endpoints_subnet_id
  postgresql_subnet_id         = module.network.postgresql_subnet_id
  tags                         = local.tags
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

module "postgresql" {
  source = "../../modules/postgresql"

  name                         = "psql-${local.name}"
  resource_group_name          = azurerm_resource_group.this.name
  location                     = azurerm_resource_group.this.location
  delegated_subnet_id          = module.network.postgresql_subnet_id
  vnet_id                      = module.network.vnet_id
  sku_name                     = var.postgresql_sku_name
  storage_mb                   = var.postgresql_storage_mb
  postgresql_version           = var.postgresql_version
  administrator_login          = var.postgresql_administrator_login
  database_name                = var.postgresql_database_name
  backup_retention_days        = var.postgresql_backup_retention_days
  geo_redundant_backup_enabled = var.postgresql_geo_redundant_backup_enabled
  high_availability_enabled    = var.postgresql_high_availability_enabled
  tags                         = local.tags
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

  enable_acr_private_endpoint = var.acr_private_endpoint_enabled
}

# Public IP for the Application Gateway's frontend. Created at root (not
# inside the appgateway module) so the Django Todo container app can depend
# on its address (for ALLOWED_HOSTS) without creating a dependency cycle
# through the gateway itself, which in turn depends on both container apps'
# FQDNs.
resource "azurerm_public_ip" "appgw" {
  name                = "pip-appgw-${local.name}"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = local.tags
}

resource "azurerm_role_assignment" "kv_admin_deployer" {
  scope                = module.keyvault.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

# ── Django Todo: managed identity + role assignments ─────────────────────
resource "azurerm_user_assigned_identity" "django_todo" {
  name                = "id-django-todo-${local.name}"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  tags                = local.tags
}

resource "azurerm_role_assignment" "django_todo_acr_pull" {
  scope                = module.containerregistry.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.django_todo.principal_id
}

resource "azurerm_role_assignment" "django_todo_kv_secrets_user" {
  scope                = module.keyvault.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.django_todo.principal_id
}

# ── Cosmos CRUD: managed identity + role assignments ──────────────────────
resource "azurerm_user_assigned_identity" "cosmos_crud" {
  name                = "id-cosmos-crud-${local.name}"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  tags                = local.tags
}

resource "azurerm_role_assignment" "cosmos_crud_acr_pull" {
  scope                = module.containerregistry.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.cosmos_crud.principal_id
}

# Built-in "Cosmos DB Built-in Data Contributor" role — control-plane RBAC
# alone does not grant Cosmos DB data-plane access.
resource "azurerm_cosmosdb_sql_role_assignment" "cosmos_crud" {
  resource_group_name = azurerm_resource_group.this.name
  account_name        = module.database.name
  role_definition_id  = "${module.database.id}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002"
  principal_id        = azurerm_user_assigned_identity.cosmos_crud.principal_id
  scope               = module.database.id
}

# ── Key Vault secrets for Django Todo ──────────────────────────────────────
# Generated once by Terraform and never rotated on re-apply (random_password
# only changes if its own arguments change), so re-applying doesn't
# invalidate active Django sessions.
resource "random_password" "django_secret_key" {
  length  = 50
  special = true
}

resource "azurerm_key_vault_secret" "django_secret_key" {
  name         = "django-secret-key"
  value        = random_password.django_secret_key.result
  key_vault_id = module.keyvault.id

  depends_on = [azurerm_role_assignment.kv_admin_deployer]
}

resource "azurerm_key_vault_secret" "postgres_password" {
  name         = "postgres-password"
  value        = module.postgresql.administrator_password
  key_vault_id = module.keyvault.id

  depends_on = [azurerm_role_assignment.kv_admin_deployer]
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
  tags                       = local.tags
}

module "django_todo" {
  source = "../../modules/containerapp"

  name                         = substr("ca-django-todo-${local.name}", 0, 32)
  resource_group_name          = azurerm_resource_group.this.name
  container_app_environment_id = module.containerapps.environment_id
  identity_id                  = azurerm_user_assigned_identity.django_todo.id
  identity_client_id           = azurerm_user_assigned_identity.django_todo.client_id
  registry_login_server        = module.containerregistry.login_server
  container_image              = var.todo_container_image
  target_port                  = var.todo_container_target_port
  cpu                          = var.container_cpu
  memory                       = var.container_memory
  min_replicas                 = var.container_app_min_replicas
  max_replicas                 = var.container_app_max_replicas
  tags                         = local.tags

  env_vars = {
    DJANGO_SETTINGS_MODULE = "taskmanager.settings.${var.django_settings_env}"
    ALLOWED_HOSTS          = join(",", [azurerm_public_ip.appgw.ip_address, "localhost", "127.0.0.1"])
    POSTGRES_DB            = module.postgresql.database_name
    POSTGRES_USER          = module.postgresql.administrator_login
    DB_HOST                = module.postgresql.fqdn
    DB_PORT                = "5432"
  }

  secrets = {
    django-secret-key = azurerm_key_vault_secret.django_secret_key.id
    postgres-password = azurerm_key_vault_secret.postgres_password.id
  }

  secret_env_vars = {
    SECRET_KEY        = "django-secret-key"
    POSTGRES_PASSWORD = "postgres-password"
  }

  depends_on = [
    azurerm_role_assignment.django_todo_acr_pull,
    azurerm_role_assignment.django_todo_kv_secrets_user,
  ]
}

module "cosmos_crud" {
  source = "../../modules/containerapp"

  name                         = substr("ca-cosmos-crud-${local.name}", 0, 32)
  resource_group_name          = azurerm_resource_group.this.name
  container_app_environment_id = module.containerapps.environment_id
  identity_id                  = azurerm_user_assigned_identity.cosmos_crud.id
  identity_client_id           = azurerm_user_assigned_identity.cosmos_crud.client_id
  registry_login_server        = module.containerregistry.login_server
  container_image              = var.cosmos_crud_container_image
  target_port                  = var.cosmos_crud_container_target_port
  cpu                          = var.container_cpu
  memory                       = var.container_memory
  min_replicas                 = var.container_app_min_replicas
  max_replicas                 = var.container_app_max_replicas
  tags                         = local.tags

  env_vars = {
    DJANGO_SETTINGS_MODULE = "cosmoscrud.settings.${var.django_settings_env}"
    ALLOWED_HOSTS          = join(",", [azurerm_public_ip.appgw.ip_address, "localhost", "127.0.0.1"])
    COSMOS_DB_ENDPOINT     = module.database.endpoint
    COSMOS_DB_DATABASE     = var.cosmosdb_database_name
    COSMOS_DB_CONTAINER    = var.cosmosdb_container_name
  }

  depends_on = [
    azurerm_role_assignment.cosmos_crud_acr_pull,
    azurerm_cosmosdb_sql_role_assignment.cosmos_crud,
  ]
}

module "appgateway" {
  source = "../../modules/appgateway"

  name_prefix         = local.name
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  subnet_id           = module.network.appgw_subnet_id
  public_ip_id        = azurerm_public_ip.appgw.id
  enable_waf          = var.enable_waf
  min_capacity        = var.appgw_min_capacity
  max_capacity        = var.appgw_max_capacity
  tags                = local.tags

  django_todo_backend_fqdn = module.django_todo.ingress_fqdn
  cosmos_crud_backend_fqdn = module.cosmos_crud.ingress_fqdn

  # The environment's private DNS zone/records (created inside the
  # containerapps module) must exist before the gateway's FQDN-based backend
  # pools can resolve them.
  depends_on = [module.containerapps]
}
