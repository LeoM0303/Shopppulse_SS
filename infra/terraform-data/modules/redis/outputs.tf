output "id" {
  description = "Managed Redis resource ID"
  value       = azurerm_managed_redis.this.id
}

output "name" {
  description = "Managed Redis name"
  value       = azurerm_managed_redis.this.name
}

output "hostname" {
  description = "Managed Redis hostname"
  value       = azurerm_managed_redis.this.hostname
}
