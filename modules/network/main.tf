resource "azurerm_virtual_network" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  address_space       = var.address_space
  tags                = var.tags
}

# Application Gateway subnet (public-facing, must be dedicated to App Gateway only)
resource "azurerm_subnet" "appgw" {
  name                 = "snet-appgw"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.appgw_subnet_prefix]
}

# Container Apps environment infrastructure subnet
resource "azurerm_subnet" "container_apps" {
  name                 = "snet-container-apps"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.container_apps_subnet_prefix]

  delegation {
    name = "Microsoft.App.environments"

    service_delegation {
      name    = "Microsoft.App/environments"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

# Private endpoints subnet (Cosmos DB, Key Vault, ACR)
resource "azurerm_subnet" "private_endpoints" {
  name                 = "snet-private-endpoints"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.private_endpoints_subnet_prefix]

  private_endpoint_network_policies = "Disabled"
}

# PostgreSQL Flexible Server subnet - Flexible Server uses VNet integration
# (not private endpoints), so it needs its own subnet delegated exclusively
# to Microsoft.DBforPostgreSQL/flexibleServers.
resource "azurerm_subnet" "postgresql" {
  name                 = "snet-postgresql"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.postgresql_subnet_prefix]

  delegation {
    name = "Microsoft.DBforPostgreSQL.flexibleServers"

    service_delegation {
      name    = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}
