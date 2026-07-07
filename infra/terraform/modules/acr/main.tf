resource "azurerm_container_registry" "this" {
  name                = substr(replace("${var.name_prefix}acr", "-", ""), 0, 50)
  resource_group_name = var.resource_group.name
  location            = var.location
  sku                 = var.sku
  admin_enabled       = false
  tags                = var.tags
}
