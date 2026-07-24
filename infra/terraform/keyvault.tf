module "keyvault" {
  source = "./modules/keyvault"

  name_prefix                   = local.name_prefix
  location                      = local.location
  tags                          = local.common_tags
  resource_group                = local.resource_group
  tenant_id                     = data.azurerm_client_config.deployer.tenant_id
  vnet_id                       = local.vnet_id
  private_endpoint_subnet_id    = local.private_endpoints_subnet_id
  identity_principal_ids        = local.identity_principal_ids
  public_network_access_enabled = var.key_vault_public_network_access_enabled
  deployer_ip_cidrs             = local.deployer_ip_cidrs
}

# RBAC for Key Vault can take ~30–60s to become effective on the data plane.
resource "time_sleep" "wait_for_kv_rbac" {
  depends_on      = [module.keyvault]
  create_duration = "60s"
}
