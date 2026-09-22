data "azurerm_client_config" "current" {}

locals {
  name_suffix  = substr(sha256(var.name_prefix), 0, 6)
  account_name = substr(replace("${var.name_prefix}data${local.name_suffix}", "-", ""), 0, 24)
}

resource "azurerm_storage_account" "this" {
  name                = local.account_name
  resource_group_name = var.resource_group.name
  location            = var.location
  tags                = var.tags

  account_tier             = "Standard"
  account_kind             = "StorageV2"
  account_replication_type = var.replication_type
  access_tier              = "Hot"

  min_tls_version                   = "TLS1_2"
  https_traffic_only_enabled        = true
  allow_nested_items_to_be_public   = false
  public_network_access_enabled     = var.public_network_access_enabled
  shared_access_key_enabled         = false
  default_to_oauth_authentication   = true
  infrastructure_encryption_enabled = true

  blob_properties {
    versioning_enabled  = true
    change_feed_enabled = false

    delete_retention_policy {
      days = var.delete_retention_days
    }

    container_delete_retention_policy {
      days = var.delete_retention_days
    }
  }

  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
    ip_rules       = [for cidr in var.deployer_ip_cidrs : split("/", cidr)[0]]
  }
}

# Data plane calls are AAD-only (shared keys are disabled), so whoever runs
# Terraform needs a data role to create containers.
resource "azurerm_role_assignment" "deployer_blob_contributor" {
  scope                = azurerm_storage_account.this.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Writers produce report snapshots, readers only list and download them.
resource "azurerm_role_assignment" "writers" {
  for_each = var.writer_principal_ids

  scope                = azurerm_storage_account.this.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = each.value
}

resource "azurerm_role_assignment" "readers" {
  for_each = var.reader_principal_ids

  scope                = azurerm_storage_account.this.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = each.value
}

resource "time_sleep" "wait_for_blob_rbac" {
  depends_on      = [azurerm_role_assignment.deployer_blob_contributor]
  create_duration = "60s"
}

resource "azurerm_storage_container" "this" {
  for_each = toset(var.container_names)

  name                  = each.value
  storage_account_id    = azurerm_storage_account.this.id
  container_access_type = "private"

  depends_on = [time_sleep.wait_for_blob_rbac]
}

# Snapshots are read for a few days, then only needed for audits, so they move
# down the tiers on their own instead of costing hot-tier money forever.
resource "azurerm_storage_management_policy" "this" {
  storage_account_id = azurerm_storage_account.this.id

  rule {
    name    = "report-snapshot-tiering"
    enabled = true

    filters {
      prefix_match = [for name in var.container_names : "${name}/"]
      blob_types   = ["blockBlob"]
    }

    actions {
      base_blob {
        tier_to_cool_after_days_since_modification_greater_than    = var.tier_to_cool_after_days
        tier_to_archive_after_days_since_modification_greater_than = var.tier_to_archive_after_days
        delete_after_days_since_modification_greater_than          = var.delete_after_days
      }

      snapshot {
        delete_after_days_since_creation_greater_than = var.delete_retention_days
      }

      version {
        delete_after_days_since_creation = var.delete_retention_days
      }
    }
  }
}

resource "azurerm_private_dns_zone" "blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = var.resource_group.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "blob" {
  name                  = "${var.name_prefix}-blob-dns-link"
  resource_group_name   = var.resource_group.name
  private_dns_zone_name = azurerm_private_dns_zone.blob.name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_private_endpoint" "blob" {
  name                = "${var.name_prefix}-blob-pe"
  location            = var.location
  resource_group_name = var.resource_group.name
  subnet_id           = var.private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "${var.name_prefix}-blob-psc"
    private_connection_resource_id = azurerm_storage_account.this.id
    is_manual_connection           = false
    subresource_names              = ["blob"]
  }

  private_dns_zone_group {
    name                 = "blob-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.blob.id]
  }

  depends_on = [azurerm_private_dns_zone_virtual_network_link.blob]
}
