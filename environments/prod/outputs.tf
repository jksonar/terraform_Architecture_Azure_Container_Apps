output "resource_group_name" {
  value = azurerm_resource_group.this.name
}

output "application_gateway_public_ip" {
  description = "Public entry point for the application. /tasks/* routes to Django Todo, /cosmos_crud/* routes to Cosmos CRUD."
  value       = azurerm_public_ip.appgw.ip_address
}

output "container_registry_login_server" {
  value = module.containerregistry.login_server
}

output "container_registry_name" {
  value = module.containerregistry.name
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

# ── Django Todo ─────────────────────────────────────────────────────────
output "django_todo_container_app_name" {
  value = module.django_todo.name
}

output "django_todo_container_app_fqdn" {
  description = "Internal FQDN of the Django Todo container app (reachable only from within the VNet)."
  value       = module.django_todo.ingress_fqdn
}

output "django_todo_managed_identity_client_id" {
  value = azurerm_user_assigned_identity.django_todo.client_id
}

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

# ── Cosmos CRUD ─────────────────────────────────────────────────────────
output "cosmos_crud_container_app_name" {
  value = module.cosmos_crud.name
}

output "cosmos_crud_container_app_fqdn" {
  description = "Internal FQDN of the Cosmos CRUD container app (reachable only from within the VNet)."
  value       = module.cosmos_crud.ingress_fqdn
}

output "cosmos_crud_managed_identity_client_id" {
  value = azurerm_user_assigned_identity.cosmos_crud.client_id
}
