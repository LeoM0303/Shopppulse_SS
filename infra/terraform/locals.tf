locals {
  name_prefix = "${var.project_name}-${var.environment}"
  common_tags = merge(
    {
      project     = var.project_name
      environment = var.environment
      managed_by  = "terraform"
    },
    var.tags
  )

  existing_rg_name = coalesce(var.resource_group_name, "${local.name_prefix}-rg")
  existing_vnet    = coalesce(var.vnet_name, "${local.name_prefix}-vnet")

  resource_group = var.create_network ? module.network[0].resource_group : {
    name     = data.azurerm_resource_group.existing[0].name
    location = data.azurerm_resource_group.existing[0].location
    id       = data.azurerm_resource_group.existing[0].id
  }

  location = local.resource_group.location
  vnet_id  = var.create_network ? module.network[0].vnet_id : data.azurerm_virtual_network.existing[0].id
  aks_subnet_id = (
    var.create_network ? module.network[0].aks_subnet_id :
    var.enable_aks ? data.azurerm_subnet.aks[0].id : null
  )
  postgres_subnet_id          = var.create_network ? module.network[0].postgres_subnet_id : data.azurerm_subnet.postgres[0].id
  private_endpoints_subnet_id = var.create_network ? module.network[0].private_endpoints_subnet_id : data.azurerm_subnet.private_endpoints[0].id

  needs_deployer_ip = (
    (var.key_vault_public_network_access_enabled && length(var.key_vault_deployer_ip_cidrs) == 0) ||
    (var.enable_storage && var.storage_public_network_access_enabled && length(var.storage_deployer_ip_cidrs) == 0)
  )

  detected_ip_cidrs = length(data.http.deployer_ip) > 0 ? ["${chomp(data.http.deployer_ip[0].response_body)}/32"] : []

  deployer_ip_cidrs = (
    !var.key_vault_public_network_access_enabled ? [] :
    length(var.key_vault_deployer_ip_cidrs) > 0 ? var.key_vault_deployer_ip_cidrs :
    local.detected_ip_cidrs
  )

  storage_ip_cidrs = (
    !var.storage_public_network_access_enabled ? [] :
    length(var.storage_deployer_ip_cidrs) > 0 ? var.storage_deployer_ip_cidrs :
    local.detected_ip_cidrs
  )

  # Ingress lives in the cluster, so it is only meaningful when there is one.
  ingress_enabled = var.enable_aks && var.enable_ingress

  identity_principal_ids = var.enable_aks ? {
    worker = module.identity[0].worker_identity.principal_id
    api    = module.identity[0].api_identity.principal_id
    keda   = module.identity[0].keda_identity.principal_id
  } : {}

  database_url = "postgresql+asyncpg://${var.postgres_admin_username}:${urlencode(random_password.postgres_admin.result)}@${module.postgresql.fqdn}:5432/${var.postgres_database_name}?ssl=require"
  redis_url    = module.redis.connection_string

  key_vault_secrets = merge(
    {
      "database-url"      = local.database_url
      "redis-url"         = local.redis_url
      "postgres-password" = random_password.postgres_admin.result
    },
    var.enable_servicebus ? {
      "servicebus-connection-string" = module.servicebus[0].primary_connection_string
      "servicebus-queue-name"        = var.servicebus_queue_names[0]
    } : {},
    var.enable_monitoring ? {
      "appinsights-connection-string" = module.monitoring[0].app_insights_connection_string
    } : {}
  )

  # Platform logs and metrics all land in the shared workspace. Redis Enterprise
  # exposes metrics but no log categories, so it is listed as metrics-only.
  diagnostic_target_ids = merge(
    {
      postgres = module.postgresql.server_id
      keyvault = module.keyvault.key_vault_id
      acr      = module.acr.id
      redis    = module.redis.id
    },
    var.enable_aks ? {
      aks = module.aks[0].cluster_id
    } : {},
    var.enable_servicebus ? {
      servicebus = module.servicebus[0].namespace_id
    } : {},
    var.enable_storage ? {
      storage_blob = "${module.storage[0].account_id}/blobServices/default"
    } : {},
    var.create_network ? {
      nsg_aks      = module.network[0].network_security_group_ids.aks
      nsg_postgres = module.network[0].network_security_group_ids.postgres
      nsg_pe       = module.network[0].network_security_group_ids.private_endpoints
    } : {}
  )
}

data "azurerm_client_config" "deployer" {}

data "http" "deployer_ip" {
  count = local.needs_deployer_ip ? 1 : 0
  url   = "https://api.ipify.org"
}
