module "identity" {
  count  = var.enable_aks ? 1 : 0
  source = "./modules/identity"

  name_prefix    = local.name_prefix
  location       = local.location
  tags           = local.common_tags
  resource_group = local.resource_group
}
