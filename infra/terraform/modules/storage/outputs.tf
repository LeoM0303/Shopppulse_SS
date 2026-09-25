output "account_id" {
  description = "Storage account resource ID"
  value       = azurerm_storage_account.this.id
}

output "account_name" {
  description = "Storage account name"
  value       = azurerm_storage_account.this.name
}

output "blob_endpoint" {
  description = "Primary blob endpoint, used as the account URL by the SDK"
  value       = azurerm_storage_account.this.primary_blob_endpoint
}

output "container_names" {
  description = "Created container names"
  value       = [for c in azurerm_storage_container.this : c.name]
}

output "file_share_name" {
  description = "Azure Files share created alongside the blob container"
  value       = azurerm_storage_share.shared.name
}
