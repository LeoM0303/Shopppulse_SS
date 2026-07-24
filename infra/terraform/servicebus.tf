module "servicebus" {
  count  = var.enable_servicebus ? 1 : 0
  source = "./modules/servicebus"

  name_prefix    = local.name_prefix
  location       = local.location
  tags           = local.common_tags
  resource_group = local.resource_group

  sku         = var.servicebus_sku
  queue_names = var.servicebus_queue_names
}
