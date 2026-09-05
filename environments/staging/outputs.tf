output "resource_group_name" {
  value = azurerm_resource_group.this.name
}

output "application_gateway_public_ip" {
  description = "Public entry point for the application."
  value       = module.appgateway.public_ip_address
}

output "container_app_fqdn" {
  description = "Internal FQDN of the container app (reachable only from within the VNet)."
  value       = module.containerapps.app_ingress_fqdn
}

output "container_registry_login_server" {
  value = module.containerregistry.login_server
}

output "key_vault_uri" {
  value = module.keyvault.vault_uri
}

output "key_vault_name" {
  value = module.keyvault.name
}

output "cosmosdb_endpoint" {
  value = module.database.endpoint
}

output "container_app_managed_identity_client_id" {
  value = azurerm_user_assigned_identity.container_app.client_id
}

output "container_app_managed_identity_id" {
  description = "Resource ID of the container app's user-assigned identity, used as the identityref when wiring Key Vault secret references into the Container App."
  value       = azurerm_user_assigned_identity.container_app.id
}

output "container_app_name" {
  value = module.containerapps.app_name
}

# Consumed by scripts/populate-keyvault-secrets.sh to seed Key Vault with the
# Django_todo_app database connection settings.
output "postgresql_fqdn" {
  value = module.postgresql.fqdn
}

output "postgresql_database_name" {
  value = module.postgresql.database_name
}

output "postgresql_administrator_login" {
  value = module.postgresql.administrator_login
}

output "postgresql_administrator_password" {
  value     = module.postgresql.administrator_password
  sensitive = true
}
