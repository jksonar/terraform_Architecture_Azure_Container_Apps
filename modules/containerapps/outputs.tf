output "environment_id" {
  value = azurerm_container_app_environment.this.id
}

output "environment_default_domain" {
  value = azurerm_container_app_environment.this.default_domain
}

output "environment_static_ip" {
  value = azurerm_container_app_environment.this.static_ip_address
}
