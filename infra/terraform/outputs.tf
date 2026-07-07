output "resource_group_name" {
  description = "Name of the resource group"
  value       = module.network.resource_group.name
}

output "aks_cluster_name" {
  description = "AKS cluster name"
  value       = module.aks.cluster_name
}

output "aks_oidc_issuer_url" {
  description = "OIDC issuer URL for Workload Identity federated credentials"
  value       = module.aks.oidc_issuer_url
}

output "postgresql_fqdn" {
  description = "PostgreSQL flexible server FQDN"
  value       = module.postgresql.fqdn
  sensitive   = true
}

output "redis_hostname" {
  description = "Redis cache hostname"
  value       = module.redis.hostname
}

output "servicebus_namespace" {
  description = "Service Bus namespace name"
  value       = module.servicebus.namespace_name
}

output "servicebus_queue_names" {
  description = "Created Service Bus queue names"
  value       = module.servicebus.queue_names
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
  description = "Client IDs for workload identities"
  value = {
    worker = module.identity.worker_identity.client_id
    api    = module.identity.api_identity.client_id
    keda   = module.identity.keda_identity.client_id
  }
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

output "get_aks_credentials_command" {
  description = "CLI command to configure kubectl"
  value       = "az aks get-credentials --resource-group ${module.network.resource_group.name} --name ${module.aks.cluster_name}"
}
