output "vnet_id" {
  value = azurerm_virtual_network.this.id
}

output "vnet_name" {
  value = azurerm_virtual_network.this.name
}

output "appgw_subnet_id" {
  value = azurerm_subnet.appgw.id
}

output "container_apps_subnet_id" {
  value = azurerm_subnet.container_apps.id
}

output "private_endpoints_subnet_id" {
  value = azurerm_subnet.private_endpoints.id
}
