# Blob storage for report snapshots. The worker writes them, the API reads them,
# and a lifecycle policy tiers and expires them without anyone touching the account.

module "storage" {
  count  = var.enable_storage ? 1 : 0
  source = "./modules/storage"

  name_prefix    = local.name_prefix
  location       = local.location
  tags           = local.common_tags
  resource_group = local.resource_group

  vnet_id                    = local.vnet_id
  private_endpoint_subnet_id = local.private_endpoints_subnet_id

  replication_type = var.storage_replication_type
  container_names  = [var.reports_container_name]

  public_network_access_enabled = var.storage_public_network_access_enabled
  deployer_ip_cidrs             = local.storage_ip_cidrs

  writer_principal_ids = var.enable_aks ? {
    worker = module.identity[0].worker_identity.principal_id
  } : {}

  reader_principal_ids = var.enable_aks ? {
    api = module.identity[0].api_identity.principal_id
  } : {}

  tier_to_cool_after_days    = var.storage_tier_to_cool_after_days
  tier_to_archive_after_days = var.storage_tier_to_archive_after_days
  delete_after_days          = var.storage_delete_after_days
}
