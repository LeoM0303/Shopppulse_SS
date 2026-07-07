resource "azurerm_key_vault_secret" "this" {
  for_each = toset(keys(nonsensitive(var.secrets)))

  name         = each.key
  value        = var.secrets[each.key]
  key_vault_id = var.key_vault_id
}
