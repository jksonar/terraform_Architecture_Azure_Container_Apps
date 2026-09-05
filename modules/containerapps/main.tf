resource "azurerm_container_app_environment" "this" {
  name                           = "cae-${var.name_prefix}"
  resource_group_name            = var.resource_group_name
  location                       = var.location
  log_analytics_workspace_id     = var.log_analytics_workspace_id
  infrastructure_subnet_id       = var.infrastructure_subnet_id
  internal_load_balancer_enabled = true
  tags                           = var.tags

  dynamic "workload_profile" {
    for_each = var.workload_profile_enabled ? [1] : []
    content {
      name                  = "Consumption"
      workload_profile_type = "Consumption"
    }
  }
}

# Private DNS zone for the environment's own default domain, so anything else
# in the VNet (e.g. the Application Gateway) can resolve the internal
# Container App FQDN to the environment's internal static IP.
resource "azurerm_private_dns_zone" "this" {
  name                = azurerm_container_app_environment.this.default_domain
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  name                  = "link-containerapps-${var.name_prefix}"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.this.name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false
}

resource "azurerm_private_dns_a_record" "apex" {
  name                = "@"
  zone_name           = azurerm_private_dns_zone.this.name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = [azurerm_container_app_environment.this.static_ip_address]
}

resource "azurerm_private_dns_a_record" "wildcard" {
  name                = "*"
  zone_name           = azurerm_private_dns_zone.this.name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = [azurerm_container_app_environment.this.static_ip_address]
}
