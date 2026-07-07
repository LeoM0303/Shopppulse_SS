resource "azurerm_managed_redis" "this" {
  name                = replace("${var.name_prefix}-redis", "-", "")
  resource_group_name = var.resource_group.name
  location            = var.location
  sku_name            = var.sku_name
  tags                = var.tags

  default_database {
    access_keys_authentication_enabled = true
  }
}
