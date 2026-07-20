locals {
  name_prefix         = "${var.project_name}-${var.environment}"
  resource_group_name = coalesce(var.resource_group_name, "${local.name_prefix}-rg")
  vnet_name           = coalesce(var.vnet_name, "${local.name_prefix}-vnet")
  common_tags = merge(
    {
      project     = var.project_name
      environment = var.environment
      managed_by  = "terraform"
    },
    var.tags
  )

  # Auto-detect public IP when temporarily opening Key Vault for laptop apply
  deployer_ip_cidrs = (
    !var.key_vault_public_network_access_enabled ? [] :
    length(var.key_vault_deployer_ip_cidrs) > 0 ? var.key_vault_deployer_ip_cidrs :
    ["${chomp(data.http.deployer_ip[0].response_body)}/32"]
  )
}

data "http" "deployer_ip" {
  count = var.key_vault_public_network_access_enabled && length(var.key_vault_deployer_ip_cidrs) == 0 ? 1 : 0
  url   = "https://api.ipify.org"
}

# ---------------------------------------------------------------------------
# Existing network — referenced only (do not create)
# ---------------------------------------------------------------------------

data "azurerm_resource_group" "this" {
  name = local.resource_group_name
}

data "azurerm_virtual_network" "this" {
  name                = local.vnet_name
  resource_group_name = data.azurerm_resource_group.this.name
}

data "azurerm_subnet" "private_endpoints" {
  name                 = var.private_endpoints_subnet_name
  virtual_network_name = data.azurerm_virtual_network.this.name
  resource_group_name  = data.azurerm_resource_group.this.name
}

data "azurerm_subnet" "postgres" {
  name                 = var.postgres_subnet_name
  virtual_network_name = data.azurerm_virtual_network.this.name
  resource_group_name  = data.azurerm_resource_group.this.name
}

data "azurerm_client_config" "current" {}

# ---------------------------------------------------------------------------
# Secrets — generated, never hardcoded
# ---------------------------------------------------------------------------

resource "random_password" "postgres" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}:?"

  lifecycle {
    ignore_changes = [length, special, override_special]
  }
}

resource "random_password" "redis" {
  length  = 32
  special = false
}

resource "random_password" "servicebus_connection_string" {
  length  = 64
  special = false
}

# ---------------------------------------------------------------------------
# Key Vault (private) — must exist before secret writes
# ---------------------------------------------------------------------------

module "keyvault" {
  source = "./modules/keyvault"

  name_prefix                   = local.name_prefix
  location                      = data.azurerm_resource_group.this.location
  tags                          = local.common_tags
  resource_group_name           = data.azurerm_resource_group.this.name
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  vnet_id                       = data.azurerm_virtual_network.this.id
  private_endpoint_subnet_id    = data.azurerm_subnet.private_endpoints.id
  public_network_access_enabled = var.key_vault_public_network_access_enabled
  deployer_ip_cidrs             = local.deployer_ip_cidrs
}

# RBAC for Key Vault can take ~30–60s to become effective on the data plane.
resource "time_sleep" "wait_for_kv_rbac" {
  depends_on      = [module.keyvault]
  create_duration = "60s"
}

resource "azurerm_key_vault_secret" "postgres_password" {
  name         = "postgres-password"
  value        = random_password.postgres.result
  key_vault_id = module.keyvault.id

  depends_on = [time_sleep.wait_for_kv_rbac]
}

resource "azurerm_key_vault_secret" "redis_password" {
  name         = "redis-password"
  value        = random_password.redis.result
  key_vault_id = module.keyvault.id

  depends_on = [time_sleep.wait_for_kv_rbac]
}

resource "azurerm_key_vault_secret" "servicebus_connection_string" {
  name         = "servicebus-connection-string"
  value        = random_password.servicebus_connection_string.result
  key_vault_id = module.keyvault.id

  depends_on = [time_sleep.wait_for_kv_rbac]
}

# ---------------------------------------------------------------------------
# ACR (Premium + private endpoint)
# ---------------------------------------------------------------------------

module "acr" {
  source = "./modules/acr"

  name_prefix                = local.name_prefix
  location                   = data.azurerm_resource_group.this.location
  tags                       = local.common_tags
  resource_group_name        = data.azurerm_resource_group.this.name
  vnet_id                    = data.azurerm_virtual_network.this.id
  private_endpoint_subnet_id = data.azurerm_subnet.private_endpoints.id
}

# ---------------------------------------------------------------------------
# Redis Cache (Premium P1 + private endpoint)
# ---------------------------------------------------------------------------

module "redis" {
  source = "./modules/redis"

  name_prefix                = local.name_prefix
  location                   = data.azurerm_resource_group.this.location
  tags                       = local.common_tags
  resource_group_name        = data.azurerm_resource_group.this.name
  vnet_id                    = data.azurerm_virtual_network.this.id
  private_endpoint_subnet_id = data.azurerm_subnet.private_endpoints.id
}

# ---------------------------------------------------------------------------
# PostgreSQL Flexible Server (VNet integration via delegated subnet)
# ---------------------------------------------------------------------------

module "postgresql" {
  source = "./modules/postgresql"

  name_prefix         = local.name_prefix
  location            = data.azurerm_resource_group.this.location
  tags                = local.common_tags
  resource_group_name = data.azurerm_resource_group.this.name
  vnet_id             = data.azurerm_virtual_network.this.id
  delegated_subnet_id = data.azurerm_subnet.postgres.id
  admin_username      = var.postgres_admin_username
  admin_password      = random_password.postgres.result
  database_name       = var.postgres_database_name

  depends_on = [azurerm_key_vault_secret.postgres_password]
}
