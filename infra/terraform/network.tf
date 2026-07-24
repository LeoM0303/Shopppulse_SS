# Network foundation — create RG/VNet/subnets, or attach to an existing VNet.

module "network" {
  count  = var.create_network ? 1 : 0
  source = "./modules/network"

  name_prefix                     = local.name_prefix
  location                        = var.location
  tags                            = local.common_tags
  vnet_address_space              = var.vnet_address_space
  aks_subnet_prefix               = var.aks_subnet_prefix
  postgres_subnet_prefix          = var.postgres_subnet_prefix
  private_endpoints_subnet_prefix = var.private_endpoints_subnet_prefix
}

data "azurerm_resource_group" "existing" {
  count = var.create_network ? 0 : 1
  name  = local.existing_rg_name
}

data "azurerm_virtual_network" "existing" {
  count               = var.create_network ? 0 : 1
  name                = local.existing_vnet
  resource_group_name = data.azurerm_resource_group.existing[0].name
}

data "azurerm_subnet" "private_endpoints" {
  count                = var.create_network ? 0 : 1
  name                 = var.private_endpoints_subnet_name
  virtual_network_name = data.azurerm_virtual_network.existing[0].name
  resource_group_name  = data.azurerm_resource_group.existing[0].name
}

data "azurerm_subnet" "postgres" {
  count                = var.create_network ? 0 : 1
  name                 = var.postgres_subnet_name
  virtual_network_name = data.azurerm_virtual_network.existing[0].name
  resource_group_name  = data.azurerm_resource_group.existing[0].name
}

data "azurerm_subnet" "aks" {
  count                = (!var.create_network && var.enable_aks) ? 1 : 0
  name                 = var.aks_subnet_name
  virtual_network_name = data.azurerm_virtual_network.existing[0].name
  resource_group_name  = data.azurerm_resource_group.existing[0].name
}
