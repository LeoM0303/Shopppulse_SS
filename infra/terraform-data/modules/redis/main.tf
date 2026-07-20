# Azure Cache for Redis (azurerm_redis_cache / Premium P1) can no longer be
# created — Azure returns: "Azure Cache for Redis is retiring, create Azure
# Managed Redis instead." See https://aka.ms/AzureCacheForRedisRetirement
#
# This module uses Azure Managed Redis with equivalent security controls:
# public access disabled, private endpoint, private DNS.

resource "azurerm_managed_redis" "this" {
  name                = replace("${var.name_prefix}-redis", "-", "")
  location            = var.location
  resource_group_name = var.resource_group_name
  # Balanced_B0 = smallest/cheapest Managed Redis SKU (dev-friendly)
  sku_name            = "Balanced_B0"
  tags                = var.tags

  public_network_access = "Disabled"

  default_database {
    access_keys_authentication_enabled = true
  }
}

resource "azurerm_private_dns_zone" "redis" {
  name                = "privatelink.redis.azure.net"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "redis" {
  name                  = "${var.name_prefix}-redis-dns-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.redis.name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_private_endpoint" "redis" {
  name                = "${var.name_prefix}-redis-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "${var.name_prefix}-redis-psc"
    private_connection_resource_id = azurerm_managed_redis.this.id
    is_manual_connection           = false
    subresource_names              = ["redisEnterprise"]
  }

  private_dns_zone_group {
    name                 = "redis-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.redis.id]
  }

  depends_on = [azurerm_private_dns_zone_virtual_network_link.redis]
}
