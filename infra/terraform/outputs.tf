output "resource_group_name" {
  description = "Name of the resource group"
  value       = local.resource_group.name
}

output "aks_cluster_name" {
  description = "AKS cluster name (null when enable_aks=false)"
  value       = try(module.aks[0].cluster_name, null)
}

output "aks_oidc_issuer_url" {
  description = "OIDC issuer URL for Workload Identity (null when enable_aks=false)"
  value       = try(module.aks[0].oidc_issuer_url, null)
}

output "postgresql_fqdn" {
  description = "PostgreSQL flexible server FQDN"
  value       = module.postgresql.fqdn
  sensitive   = true
}

output "redis_hostname" {
  description = "Managed Redis hostname"
  value       = module.redis.hostname
}

output "servicebus_namespace" {
  description = "Service Bus namespace name (null when enable_servicebus=false)"
  value       = try(module.servicebus[0].namespace_name, null)
}

output "servicebus_queue_names" {
  description = "Created Service Bus queue names"
  value       = try(module.servicebus[0].queue_names, [])
}

output "key_vault_name" {
  description = "Key Vault name for application secrets"
  value       = module.keyvault.key_vault_name
}

output "key_vault_uri" {
  description = "Key Vault URI"
  value       = module.keyvault.key_vault_uri
}

output "identity_client_ids" {
  description = "Client IDs for workload identities (empty when enable_aks=false)"
  value = var.enable_aks ? {
    worker = module.identity[0].worker_identity.client_id
    api    = module.identity[0].api_identity.client_id
    keda   = module.identity[0].keda_identity.client_id
  } : {}
}

output "k8s_namespace" {
  description = "Kubernetes namespace for ShopPulse workloads"
  value       = var.k8s_namespace
}

output "acr_login_server" {
  description = "ACR login server for docker push"
  value       = module.acr.login_server
}

output "acr_name" {
  description = "ACR registry name"
  value       = module.acr.name
}

output "log_analytics_workspace_name" {
  description = "Log Analytics workspace that holds platform, container and application telemetry (null when enable_monitoring=false)"
  value       = try(module.monitoring[0].workspace_name, null)
}

output "app_insights_name" {
  description = "Application Insights component name (null when enable_monitoring=false)"
  value       = try(module.monitoring[0].app_insights_name, null)
}

output "reports_storage_account_url" {
  description = "Blob endpoint the application uses for report snapshots (null when enable_storage=false)"
  value       = try(module.storage[0].blob_endpoint, null)
}

output "reports_container_name" {
  description = "Container that holds report snapshots (null when enable_storage=false)"
  value       = var.enable_storage ? var.reports_container_name : null
}

output "get_aks_credentials_command" {
  description = "CLI command to configure kubectl (empty when enable_aks=false)"
  value = var.enable_aks ? (
    "az aks get-credentials --resource-group ${local.resource_group.name} --name ${module.aks[0].cluster_name}"
  ) : null
}
