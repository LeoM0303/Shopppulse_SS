output "resource_group_name" {
  description = "Existing resource group used by this stack"
  value       = data.azurerm_resource_group.this.name
}

output "acr_name" {
  description = "Azure Container Registry name"
  value       = module.acr.name
}

output "acr_login_server" {
  description = "ACR login server"
  value       = module.acr.login_server
}

output "key_vault_name" {
  description = "Key Vault name"
  value       = module.keyvault.name
}

output "key_vault_uri" {
  description = "Key Vault URI"
  value       = module.keyvault.uri
}

output "redis_hostname" {
  description = "Redis Cache hostname"
  value       = module.redis.hostname
}

output "postgresql_server_name" {
  description = "PostgreSQL Flexible Server name"
  value       = module.postgresql.name
}

output "postgresql_database_name" {
  description = "Application database name"
  value       = module.postgresql.database_name
}

output "key_vault_secret_names" {
  description = "Secrets stored in Key Vault"
  value = [
    azurerm_key_vault_secret.postgres_password.name,
    azurerm_key_vault_secret.redis_password.name,
    azurerm_key_vault_secret.servicebus_connection_string.name,
  ]
}
