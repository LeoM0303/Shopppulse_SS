output "key_vault_id" {
  description = "Key Vault resource ID"
  value       = azurerm_key_vault.this.id
}

output "key_vault_name" {
  description = "Key Vault name"
  value       = azurerm_key_vault.this.name
}

output "key_vault_uri" {
  description = "Key Vault URI"
  value       = azurerm_key_vault.this.vault_uri
}

output "deployer_role_assignment_id" {
  description = "Deployer Secrets Officer role assignment (for depends_on / time_sleep)"
  value       = azurerm_role_assignment.deployer_secrets_officer.id
}
