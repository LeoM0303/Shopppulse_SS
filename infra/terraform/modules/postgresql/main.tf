locals {
  server_name    = "${var.name_prefix}-psql"
  dns_zone_name  = "${var.name_prefix}.postgres.database.azure.com"
}

resource "azurerm_private_dns_zone" "this" {
  name                = local.dns_zone_name
  resource_group_name = var.resource_group.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  name                  = "${var.name_prefix}-psql-dns-link"
  resource_group_name   = var.resource_group.name
  private_dns_zone_name = azurerm_private_dns_zone.this.name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_postgresql_flexible_server" "this" {
  name                   = local.server_name
  location               = var.location
  resource_group_name    = var.resource_group.name
  version                = "16"
  administrator_login    = var.admin_username
  administrator_password = var.admin_password
  storage_mb             = var.storage_mb
  sku_name               = var.sku_name
  zone                   = "1"
  tags                   = var.tags

  delegated_subnet_id = var.subnet_id
  private_dns_zone_id = azurerm_private_dns_zone.this.id

  public_network_access_enabled = false

  authentication {
    password_auth_enabled = true
  }

  depends_on = [azurerm_private_dns_zone_virtual_network_link.this]

  lifecycle {
    ignore_changes = [zone]
  }
}

resource "azurerm_postgresql_flexible_server_database" "app" {
  name      = var.database_name
  server_id = azurerm_postgresql_flexible_server.this.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

resource "azurerm_postgresql_flexible_server_configuration" "extensions" {
  name      = "azure.extensions"
  server_id = azurerm_postgresql_flexible_server.this.id
  value     = "UUID-OSSP"
}
