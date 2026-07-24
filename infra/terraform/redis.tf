module "redis" {
  source = "./modules/redis"

  name_prefix                = local.name_prefix
  location                   = local.location
  tags                       = local.common_tags
  resource_group             = local.resource_group
  vnet_id                    = local.vnet_id
  private_endpoint_subnet_id = local.private_endpoints_subnet_id
  sku_name                   = var.redis_sku_name
}
