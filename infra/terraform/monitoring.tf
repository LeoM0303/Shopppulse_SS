# Observability — one Log Analytics workspace collects platform logs, container
# logs and application telemetry, and alerts fan out through a single action group.

module "monitoring" {
  count  = var.enable_monitoring ? 1 : 0
  source = "./modules/monitoring"

  name_prefix    = local.name_prefix
  location       = local.location
  tags           = local.common_tags
  resource_group = local.resource_group

  retention_in_days   = var.log_retention_days
  daily_quota_gb      = var.log_daily_quota_gb
  sampling_percentage = var.app_insights_sampling_percentage
  alert_email         = var.alert_email

  k8s_namespace      = var.k8s_namespace
  aks_enabled        = var.enable_aks
  aks_cluster_id     = try(module.aks[0].cluster_id, null)
  postgres_server_id = module.postgresql.server_id

  diagnostic_target_ids = local.diagnostic_target_ids
  metrics_only_targets  = ["redis"]
}
