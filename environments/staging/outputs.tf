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

output "cosmosdb_endpoint" {
  value = module.database.endpoint
}

output "container_app_managed_identity_client_id" {
  value = azurerm_user_assigned_identity.container_app.client_id
}
