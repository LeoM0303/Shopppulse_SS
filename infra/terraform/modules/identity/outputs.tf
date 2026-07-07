output "tenant_id" {
  description = "Azure AD tenant ID"
  value       = data.azurerm_client_config.current.tenant_id
}

output "aks_identity" {
  description = "User-assigned identity for AKS cluster control plane"
  value = {
    id           = azurerm_user_assigned_identity.aks.id
    client_id    = azurerm_user_assigned_identity.aks.client_id
    principal_id = azurerm_user_assigned_identity.aks.principal_id
  }
}

output "kubelet_identity" {
  description = "User-assigned identity for AKS kubelet"
  value = {
    id           = azurerm_user_assigned_identity.kubelet.id
    client_id    = azurerm_user_assigned_identity.kubelet.client_id
    principal_id = azurerm_user_assigned_identity.kubelet.principal_id
  }
}

output "worker_identity" {
  description = "Workload identity for the worker service"
  value = {
    id           = azurerm_user_assigned_identity.worker.id
    client_id    = azurerm_user_assigned_identity.worker.client_id
    principal_id = azurerm_user_assigned_identity.worker.principal_id
  }
}

output "api_identity" {
  description = "Workload identity for the API service"
  value = {
    id           = azurerm_user_assigned_identity.api.id
    client_id    = azurerm_user_assigned_identity.api.client_id
    principal_id = azurerm_user_assigned_identity.api.principal_id
  }
}

output "keda_identity" {
  description = "Workload identity for KEDA Service Bus scaler"
  value = {
    id           = azurerm_user_assigned_identity.keda.id
    client_id    = azurerm_user_assigned_identity.keda.client_id
    principal_id = azurerm_user_assigned_identity.keda.principal_id
  }
}
