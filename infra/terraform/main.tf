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
}

# 1. Network — foundation for all VNet-integrated resources

module "network" {
  source = "./modules/network"

  name_prefix                     = local.name_prefix
  location                        = var.location
  tags                            = local.common_tags
  vnet_address_space              = var.vnet_address_space
  aks_subnet_prefix               = var.aks_subnet_prefix
  postgres_subnet_prefix          = var.postgres_subnet_prefix
  private_endpoints_subnet_prefix = var.private_endpoints_subnet_prefix
}

# 2. Identity — user-assigned identities (federated creds wired after AKS)
module "identity" {
  source = "./modules/identity"

  name_prefix    = local.name_prefix
  location       = var.location
  tags           = local.common_tags
  resource_group = module.network.resource_group
}

# 3. Key Vault — stores generated secrets (populated after data services)

module "keyvault" {
  source = "./modules/keyvault"

  name_prefix    = local.name_prefix
  location       = var.location
  tags           = local.common_tags
  resource_group = module.network.resource_group
  tenant_id      = module.identity.tenant_id

  identity_principal_ids = {
    worker = module.identity.worker_identity.principal_id
    api    = module.identity.api_identity.principal_id
    keda   = module.identity.keda_identity.principal_id
  }
}

# 4. PostgreSQL — VNet-integrated flexible server

resource "random_password" "postgres_admin" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}:?"

  lifecycle {
    ignore_changes = [length, special, override_special]
  }
}

module "postgresql" {
  source = "./modules/postgresql"

  name_prefix    = local.name_prefix
  location       = var.location
  tags           = local.common_tags
  resource_group = module.network.resource_group

  subnet_id          = module.network.postgres_subnet_id
  vnet_id            = module.network.vnet_id

  admin_username = var.postgres_admin_username
  admin_password  = random_password.postgres_admin.result
  database_name   = var.postgres_database_name
  sku_name        = var.postgres_sku_name
  storage_mb      = var.postgres_storage_mb
}

# 5. Redis

module "redis" {
  source = "./modules/redis"

  name_prefix    = local.name_prefix
  location       = var.location
  tags           = local.common_tags
  resource_group = module.network.resource_group

  sku_name = var.redis_sku_name
}

# 6. Service Bus — namespace + queues from servicebus-config.json

module "servicebus" {
  source = "./modules/servicebus"

  name_prefix    = local.name_prefix
  location       = var.location
  tags           = local.common_tags
  resource_group = module.network.resource_group

  sku         = var.servicebus_sku
  queue_names = var.servicebus_queue_names
}


# 6b. Azure Container Registry

data "azurerm_client_config" "deployer" {}

module "acr" {
  source = "./modules/acr"

  name_prefix    = local.name_prefix
  location       = var.location
  tags           = local.common_tags
  resource_group = module.network.resource_group
}

resource "azurerm_role_assignment" "kubelet_acr_pull" {
  scope                = module.acr.id
  role_definition_name = "AcrPull"
  principal_id         = module.identity.kubelet_identity.principal_id
}

resource "azurerm_role_assignment" "deployer_acr_push" {
  scope                = module.acr.id
  role_definition_name = "AcrPush"
  principal_id         = data.azurerm_client_config.deployer.object_id
}

# AKS identity RBAC prerequisites

resource "azurerm_role_assignment" "aks_identity_operator" {
  scope                = module.identity.kubelet_identity.id
  role_definition_name = "Managed Identity Operator"
  principal_id         = module.identity.aks_identity.principal_id
}

resource "azurerm_role_assignment" "kubelet_network_contributor" {
  scope                = module.network.aks_subnet_id
  role_definition_name = "Network Contributor"
  principal_id         = module.identity.kubelet_identity.principal_id
}

resource "azurerm_role_assignment" "aks_contributor" {
  scope                = module.network.resource_group.id
  role_definition_name = "Contributor"
  principal_id         = module.identity.aks_identity.principal_id
}

# 7. AKS — cluster with KEDA, Workload Identity, OIDC issuer

module "aks" {
  source = "./modules/aks"

  name_prefix    = local.name_prefix
  location       = var.location
  tags           = local.common_tags
  resource_group = module.network.resource_group

  subnet_id           = module.network.aks_subnet_id
  cluster_identity_id = module.identity.aks_identity.id
  kubelet_identity    = module.identity.kubelet_identity
  kubernetes_version  = var.kubernetes_version

  system_node_vm_size   = var.system_node_vm_size
  system_node_count     = var.system_node_count
  workload_node_vm_size = var.workload_node_vm_size
  workload_node_min     = var.workload_node_min_count
  workload_node_max     = var.workload_node_max_count

  depends_on = [
    azurerm_role_assignment.aks_identity_operator,
    azurerm_role_assignment.kubelet_network_contributor,
    azurerm_role_assignment.aks_contributor,
  ]
}

# Grant the Terraform deployer kubectl access (AKS uses Azure RBAC)
resource "azurerm_role_assignment" "deployer_aks_rbac_admin" {
  scope                = module.aks.cluster_id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = data.azurerm_client_config.deployer.object_id
}

# 8. Workload Identity federated credentials (require AKS OIDC issuer URL)

resource "azurerm_federated_identity_credential" "keda_servicebus" {
  name      = "${local.name_prefix}-keda-sb-fic"
  audience  = ["api://AzureADTokenExchange"]
  issuer    = module.aks.oidc_issuer_url
  parent_id = module.identity.keda_identity.id
  subject   = "system:serviceaccount:${var.k8s_namespace}:${var.keda_service_account_name}"
}

resource "azurerm_federated_identity_credential" "worker" {
  name      = "${local.name_prefix}-worker-fic"
  audience  = ["api://AzureADTokenExchange"]
  issuer    = module.aks.oidc_issuer_url
  parent_id = module.identity.worker_identity.id
  subject   = "system:serviceaccount:${var.k8s_namespace}:${var.worker_service_account_name}"
}

resource "azurerm_federated_identity_credential" "api" {
  name      = "${local.name_prefix}-api-fic"
  audience  = ["api://AzureADTokenExchange"]
  issuer    = module.aks.oidc_issuer_url
  parent_id = module.identity.api_identity.id
  subject   = "system:serviceaccount:${var.k8s_namespace}:${var.api_service_account_name}"
}

# 9. RBAC — grant identities access to Azure services

resource "azurerm_role_assignment" "keda_servicebus_receiver" {
  scope                = module.servicebus.namespace_id
  role_definition_name = "Azure Service Bus Data Receiver"
  principal_id         = module.identity.keda_identity.principal_id
}

resource "azurerm_role_assignment" "worker_servicebus_receiver" {
  scope                = module.servicebus.namespace_id
  role_definition_name = "Azure Service Bus Data Receiver"
  principal_id         = module.identity.worker_identity.principal_id
}

resource "azurerm_role_assignment" "api_servicebus_sender" {
  scope                = module.servicebus.namespace_id
  role_definition_name = "Azure Service Bus Data Sender"
  principal_id         = module.identity.api_identity.principal_id
}


# 10. Key Vault secrets — connection strings built from module outputs

locals {
  database_url = "postgresql+asyncpg://${var.postgres_admin_username}:${urlencode(random_password.postgres_admin.result)}@${module.postgresql.fqdn}:5432/${var.postgres_database_name}?ssl=require"
  redis_url    = module.redis.connection_string
}

module "keyvault_secrets" {
  source = "./modules/keyvault/secrets"

  key_vault_id = module.keyvault.key_vault_id

  secrets = {
    "database-url" = local.database_url
    "redis-url"    = local.redis_url
    "servicebus-connection-string" = module.servicebus.primary_connection_string
    "servicebus-queue-name"        = var.servicebus_queue_names[0]
  }

  depends_on = [
    module.keyvault,
    module.postgresql,
    module.redis,
    module.servicebus,
  ]
}

# 11. Kubernetes — namespace and service accounts for Workload Identity

resource "kubernetes_namespace" "shoppulse" {
  metadata {
    name = var.k8s_namespace
    labels = {
      "app.kubernetes.io/part-of" = var.project_name
    }
  }

  depends_on = [module.aks]
}

resource "kubernetes_service_account" "keda_servicebus" {
  metadata {
    name      = var.keda_service_account_name
    namespace = kubernetes_namespace.shoppulse.metadata[0].name
    labels = {
      "azure.workload.identity/use" = "true"
    }
    annotations = {
      "azure.workload.identity/client-id" = module.identity.keda_identity.client_id
    }
  }
}

resource "kubernetes_service_account" "worker" {
  metadata {
    name      = var.worker_service_account_name
    namespace = kubernetes_namespace.shoppulse.metadata[0].name
    labels = {
      "azure.workload.identity/use" = "true"
    }
    annotations = {
      "azure.workload.identity/client-id" = module.identity.worker_identity.client_id
    }
  }
}

resource "kubernetes_service_account" "api" {
  metadata {
    name      = var.api_service_account_name
    namespace = kubernetes_namespace.shoppulse.metadata[0].name
    labels = {
      "azure.workload.identity/use" = "true"
    }
    annotations = {
      "azure.workload.identity/client-id" = module.identity.api_identity.client_id
    }
  }
}
