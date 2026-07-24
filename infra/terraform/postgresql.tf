resource "random_password" "postgres_admin" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}:?"

  lifecycle {
    ignore_changes = [length, special, override_special]
  }
}

module "postgresql" {
  source = "./modules/postgresql"

  name_prefix    = local.name_prefix
  location       = local.location
  tags           = local.common_tags
  resource_group = local.resource_group

  subnet_id  = local.postgres_subnet_id
  vnet_id    = local.vnet_id
  admin_username = var.postgres_admin_username
  admin_password = random_password.postgres_admin.result
  database_name  = var.postgres_database_name
  sku_name       = var.postgres_sku_name
  storage_mb     = var.postgres_storage_mb
}
