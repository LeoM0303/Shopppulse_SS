# Network Watcher plus a VNet flow log. The junior network task asks for
# something that can explain why a packet was allowed or denied after the fact;
# NSG rules alone cannot.

resource "azurerm_network_watcher" "this" {
  count = var.create_network && var.enable_storage ? 1 : 0

  name                = "${local.name_prefix}-nw"
  location            = local.location
  resource_group_name = local.resource_group.name
  tags                = local.common_tags
}

resource "azurerm_network_watcher_flow_log" "app" {
  count = var.create_network && var.enable_storage ? 1 : 0

  name                 = "${local.name_prefix}-vnet-flow"
  network_watcher_name = azurerm_network_watcher.this[0].name
  resource_group_name  = local.resource_group.name
  target_resource_id   = module.network[0].vnet_id
  storage_account_id   = module.storage[0].account_id
  enabled              = true
  version              = 2

  retention_policy {
    enabled = true
    days    = 7
  }
}
