data "azurerm_client_config" "current" {}

locals {
  name_suffix = substr(sha256(var.name_prefix), 0, 4)
}

resource "azurerm_key_vault" "this" {
  name                       = substr(replace("${var.name_prefix}kv${local.name_suffix}", "-", ""), 0, 24)
  location                   = var.location
  resource_group_name        = var.resource_group.name
  tenant_id                  = var.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
  rbac_authorization_enabled = true
  tags                       = var.tags
}

resource "azurerm_role_assignment" "deployer" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_role_assignment" "workload_secrets_user" {
  for_each = var.identity_principal_ids

  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = each.value
}
