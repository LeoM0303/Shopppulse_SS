output "namespace_id" {
  description = "Service Bus namespace resource ID"
  value       = azurerm_servicebus_namespace.this.id
}

output "namespace_name" {
  description = "Service Bus namespace name"
  value       = azurerm_servicebus_namespace.this.name
}

output "queue_names" {
  description = "Created queue names"
  value       = [for q in azurerm_servicebus_queue.this : q.name]
}

output "primary_connection_string" {
  description = "Service Bus namespace primary connection string"
  value       = azurerm_servicebus_namespace.this.default_primary_connection_string
  sensitive   = true
}
