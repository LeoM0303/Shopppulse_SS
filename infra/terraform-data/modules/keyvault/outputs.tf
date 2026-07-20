output "id" {
  description = "Key Vault resource ID"
  value       = azurerm_key_vault.this.id
}

output "name" {
  description = "Key Vault name"
  value       = azurerm_key_vault.this.name
}

output "uri" {
  description = "Key Vault URI"
  value       = azurerm_key_vault.this.vault_uri
}

output "deployer_role_assignment_id" {
  description = "Role assignment ID for deployer secrets access (for depends_on)"
  value       = azurerm_role_assignment.deployer_secrets_officer.id
}
