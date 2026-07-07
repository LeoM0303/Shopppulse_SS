output "secret_ids" {
  description = "Map of secret name to secret resource ID"
  value       = { for k, v in azurerm_key_vault_secret.this : k => v.id }
}

output "secret_names" {
  description = "List of created secret names"
  value       = keys(azurerm_key_vault_secret.this)
}
