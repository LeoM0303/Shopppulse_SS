data "azurerm_client_config" "current" {}

resource "azurerm_user_assigned_identity" "aks" {
  name                = "${var.name_prefix}-aks-identity"
  location            = var.location
  resource_group_name = var.resource_group.name
  tags                = var.tags
}

# Kubelet identity is managed by AKS but referenced for role assignments
resource "azurerm_user_assigned_identity" "kubelet" {
  name                = "${var.name_prefix}-kubelet-identity"
  location            = var.location
  resource_group_name = var.resource_group.name
  tags                = var.tags
}

resource "azurerm_user_assigned_identity" "worker" {
  name                = "${var.name_prefix}-worker-identity"
  location            = var.location
  resource_group_name = var.resource_group.name
  tags                = var.tags
}

resource "azurerm_user_assigned_identity" "api" {
  name                = "${var.name_prefix}-api-identity"
  location            = var.location
  resource_group_name = var.resource_group.name
  tags                = var.tags
}

resource "azurerm_user_assigned_identity" "keda" {
  name                = "${var.name_prefix}-keda-identity"
  location            = var.location
  resource_group_name = var.resource_group.name
  tags                = var.tags
}
