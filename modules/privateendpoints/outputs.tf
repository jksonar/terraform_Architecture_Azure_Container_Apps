output "acr_private_endpoint_id" {
  value = try(azurerm_private_endpoint.acr[0].id, null)
}

output "key_vault_private_endpoint_id" {
  value = azurerm_private_endpoint.key_vault.id
}

output "cosmos_private_endpoint_id" {
  value = azurerm_private_endpoint.cosmos.id
}
