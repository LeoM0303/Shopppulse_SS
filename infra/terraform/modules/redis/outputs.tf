output "id" {
  description = "Managed Redis resource ID"
  value       = azurerm_managed_redis.this.id
}

output "hostname" {
  description = "Redis hostname"
  value       = azurerm_managed_redis.this.hostname
}

output "port" {
  description = "Redis TLS port"
  value       = azurerm_managed_redis.this.default_database[0].port
}

output "primary_access_key" {
  description = "Redis primary access key"
  value       = azurerm_managed_redis.this.default_database[0].primary_access_key
  sensitive   = true
}

output "connection_string" {
  description = "Redis connection string (TLS)"
  value       = "rediss://:${azurerm_managed_redis.this.default_database[0].primary_access_key}@${azurerm_managed_redis.this.hostname}:${azurerm_managed_redis.this.default_database[0].port}/0"
  sensitive   = true
}
