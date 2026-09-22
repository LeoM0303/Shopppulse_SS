output "workspace_id" {
  description = "Log Analytics workspace resource ID"
  value       = azurerm_log_analytics_workspace.this.id
}

output "workspace_name" {
  description = "Log Analytics workspace name"
  value       = azurerm_log_analytics_workspace.this.name
}

output "app_insights_connection_string" {
  description = "Application Insights connection string for the SDK"
  value       = azurerm_application_insights.this.connection_string
  sensitive   = true
}

output "app_insights_name" {
  description = "Application Insights component name"
  value       = azurerm_application_insights.this.name
}

output "action_group_id" {
  description = "Action group that receives alerts"
  value       = azurerm_monitor_action_group.this.id
}
