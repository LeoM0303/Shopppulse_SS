resource "azurerm_role_assignment" "aks_identity_operator" {
  count = var.enable_aks ? 1 : 0

  scope                = module.identity[0].kubelet_identity.id
  role_definition_name = "Managed Identity Operator"
  principal_id         = module.identity[0].aks_identity.principal_id
}

resource "azurerm_role_assignment" "kubelet_network_contributor" {
  count = var.enable_aks ? 1 : 0

  scope                = local.aks_subnet_id
  role_definition_name = "Network Contributor"
  principal_id         = module.identity[0].kubelet_identity.principal_id
}

resource "azurerm_role_assignment" "aks_contributor" {
  count = var.enable_aks ? 1 : 0

  scope                = local.resource_group.id
  role_definition_name = "Contributor"
  principal_id         = module.identity[0].aks_identity.principal_id
}

module "aks" {
  count  = var.enable_aks ? 1 : 0
  source = "./modules/aks"

  name_prefix    = local.name_prefix
  location       = local.location
  tags           = local.common_tags
  resource_group = local.resource_group

  subnet_id           = local.aks_subnet_id
  cluster_identity_id = module.identity[0].aks_identity.id
  kubelet_identity    = module.identity[0].kubelet_identity
  kubernetes_version  = var.kubernetes_version

  system_node_vm_size   = var.system_node_vm_size
  system_node_count     = var.system_node_count
  workload_node_vm_size = var.workload_node_vm_size
  workload_node_min     = var.workload_node_min_count
  workload_node_max     = var.workload_node_max_count

  log_analytics_workspace_id = try(module.monitoring[0].workspace_id, null)

  depends_on = [
    azurerm_role_assignment.aks_identity_operator,
    azurerm_role_assignment.kubelet_network_contributor,
    azurerm_role_assignment.aks_contributor,
  ]
}

resource "azurerm_role_assignment" "deployer_aks_rbac_admin" {
  count = var.enable_aks ? 1 : 0

  scope                = module.aks[0].cluster_id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = data.azurerm_client_config.deployer.object_id
}

resource "azurerm_federated_identity_credential" "keda_servicebus" {
  count = var.enable_aks ? 1 : 0

  name      = "${local.name_prefix}-keda-sb-fic"
  audience  = ["api://AzureADTokenExchange"]
  issuer    = module.aks[0].oidc_issuer_url
  parent_id = module.identity[0].keda_identity.id
  subject   = "system:serviceaccount:${var.k8s_namespace}:${var.keda_service_account_name}"
}

resource "azurerm_federated_identity_credential" "worker" {
  count = var.enable_aks ? 1 : 0

  name      = "${local.name_prefix}-worker-fic"
  audience  = ["api://AzureADTokenExchange"]
  issuer    = module.aks[0].oidc_issuer_url
  parent_id = module.identity[0].worker_identity.id
  subject   = "system:serviceaccount:${var.k8s_namespace}:${var.worker_service_account_name}"
}

resource "azurerm_federated_identity_credential" "api" {
  count = var.enable_aks ? 1 : 0

  name      = "${local.name_prefix}-api-fic"
  audience  = ["api://AzureADTokenExchange"]
  issuer    = module.aks[0].oidc_issuer_url
  parent_id = module.identity[0].api_identity.id
  subject   = "system:serviceaccount:${var.k8s_namespace}:${var.api_service_account_name}"
}

resource "azurerm_role_assignment" "keda_servicebus_receiver" {
  count = var.enable_aks && var.enable_servicebus ? 1 : 0

  scope                = module.servicebus[0].namespace_id
  role_definition_name = "Azure Service Bus Data Receiver"
  principal_id         = module.identity[0].keda_identity.principal_id
}

resource "azurerm_role_assignment" "worker_servicebus_receiver" {
  count = var.enable_aks && var.enable_servicebus ? 1 : 0

  scope                = module.servicebus[0].namespace_id
  role_definition_name = "Azure Service Bus Data Receiver"
  principal_id         = module.identity[0].worker_identity.principal_id
}

resource "azurerm_role_assignment" "api_servicebus_sender" {
  count = var.enable_aks && var.enable_servicebus ? 1 : 0

  scope                = module.servicebus[0].namespace_id
  role_definition_name = "Azure Service Bus Data Sender"
  principal_id         = module.identity[0].api_identity.principal_id
}
