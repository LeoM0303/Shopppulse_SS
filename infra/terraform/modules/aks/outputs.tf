output "cluster_name" {
  description = "AKS cluster name"
  value       = azurerm_kubernetes_cluster.this.name
}

output "cluster_id" {
  description = "AKS cluster resource ID"
  value       = azurerm_kubernetes_cluster.this.id
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL for Workload Identity"
  value       = azurerm_kubernetes_cluster.this.oidc_issuer_url
}

output "kube_admin_config" {
  description = "Admin kubeconfig block for kubernetes/helm providers"
  value       = azurerm_kubernetes_cluster.this.kube_admin_config
  sensitive   = true
}

output "kube_config" {
  description = "User kubeconfig block"
  value       = azurerm_kubernetes_cluster.this.kube_config
  sensitive   = true
}

output "node_resource_group" {
  description = "Auto-generated node resource group name"
  value       = azurerm_kubernetes_cluster.this.node_resource_group
}
