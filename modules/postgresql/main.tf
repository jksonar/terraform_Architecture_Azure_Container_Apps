# Flexible Server has no private-endpoint support - it's reachable only via
# VNet integration into its own delegated subnet, resolved through a private
# DNS zone linked to the VNet (this is the "Private access" networking mode).
resource "azurerm_private_dns_zone" "postgresql" {
  name                = "privatelink.postgres.database.azure.com"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgresql" {
  name                  = "link-postgresql-${var.name}"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.postgresql.name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false
}

# Not stored anywhere but Terraform state and this module's sensitive output;
# the caller's bash script reads it via `terraform output` to seed Key Vault.
resource "random_password" "administrator" {
  length           = 24
  special          = true
  override_special = "-_=+"
}

resource "azurerm_postgresql_flexible_server" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  version    = var.postgresql_version
  sku_name   = var.sku_name
  storage_mb = var.storage_mb

  administrator_login    = var.administrator_login
  administrator_password = random_password.administrator.result

  delegated_subnet_id           = var.delegated_subnet_id
  private_dns_zone_id           = azurerm_private_dns_zone.postgresql.id
  public_network_access_enabled = false

  backup_retention_days        = var.backup_retention_days
  geo_redundant_backup_enabled = var.geo_redundant_backup_enabled

  dynamic "high_availability" {
    for_each = var.high_availability_enabled ? [1] : []
    content {
      mode = "ZoneRedundant"
    }
  }

  depends_on = [azurerm_private_dns_zone_virtual_network_link.postgresql]

  lifecycle {
    ignore_changes = [zone, high_availability[0].standby_availability_zone]
  }
}

resource "azurerm_postgresql_flexible_server_database" "this" {
  name      = var.database_name
  server_id = azurerm_postgresql_flexible_server.this.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}
