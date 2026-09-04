output "id" {
  value = azurerm_log_analytics_workspace.this.id
}

output "workspace_id" {
  description = "Log Analytics workspace (customer) ID."
  value       = azurerm_log_analytics_workspace.this.workspace_id
}
