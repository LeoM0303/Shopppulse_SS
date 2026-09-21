module "acr" {
  source = "./modules/acr"

  name_prefix                = local.name_prefix
  location                   = local.location
  tags                       = local.common_tags
  resource_group             = local.resource_group
  vnet_id                    = local.vnet_id
  private_endpoint_subnet_id = local.private_endpoints_subnet_id
  sku                        = var.acr_sku

  public_network_access_enabled = var.acr_public_network_access_enabled
  allowed_ip_cidrs              = var.acr_allowed_ip_cidrs
}

resource "azurerm_role_assignment" "kubelet_acr_pull" {
  count = var.enable_aks ? 1 : 0

  scope                = module.acr.id
  role_definition_name = "AcrPull"
  principal_id         = module.identity[0].kubelet_identity.principal_id
}

resource "azurerm_role_assignment" "deployer_acr_push" {
  count = var.enable_aks ? 1 : 0

  scope                = module.acr.id
  role_definition_name = "AcrPush"
  principal_id         = data.azurerm_client_config.deployer.object_id
}
