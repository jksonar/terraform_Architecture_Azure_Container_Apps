output "id" {
  value = azurerm_postgresql_flexible_server.this.id
}

output "name" {
  value = azurerm_postgresql_flexible_server.this.name
}

output "fqdn" {
  value = azurerm_postgresql_flexible_server.this.fqdn
}

output "database_name" {
  value = azurerm_postgresql_flexible_server_database.this.name
}

output "administrator_login" {
  value = azurerm_postgresql_flexible_server.this.administrator_login
}

output "administrator_password" {
  value     = random_password.administrator.result
  sensitive = true
}
