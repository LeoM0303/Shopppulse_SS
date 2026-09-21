variable "subscription_id" {
  description = "Azure subscription ID. Prefer ARM_SUBSCRIPTION_ID env if null."
  type        = string
  default     = null
  nullable    = true
}

variable "location" {
  description = "Azure region (used when create_network=true). Ignored when attaching to an existing RG."
  type        = string
  default     = "polandcentral"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name used as prefix for resource names"
  type        = string
  default     = "shoppulse"
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}

# --- Modes ---

variable "create_network" {
  description = "true = create RG/VNet/subnets. false = use existing network via data sources."
  type        = bool
  default     = true
}

variable "enable_aks" {
  description = "true = identity, AKS, Workload Identity, K8s SAs, ACR pull roles. false = data plane only."
  type        = bool
  default     = true
}

variable "enable_servicebus" {
  description = "true = Service Bus namespace + queues + KV secrets. false = skip messaging."
  type        = bool
  default     = true
}

# --- Existing network (create_network=false) ---

variable "resource_group_name" {
  description = "Existing RG name. Default: {project}-{environment}-rg"
  type        = string
  default     = null
  nullable    = true
}

variable "vnet_name" {
  description = "Existing VNet name. Default: {project}-{environment}-vnet"
  type        = string
  default     = null
  nullable    = true
}

variable "private_endpoints_subnet_name" {
  type    = string
  default = "private-endpoints"
}

variable "postgres_subnet_name" {
  type    = string
  default = "postgres"
}

variable "aks_subnet_name" {
  description = "Existing AKS subnet name (required when create_network=false and enable_aks=true)"
  type        = string
  default     = "aks"
}

# --- Network (create_network=true) ---

variable "vnet_address_space" {
  type    = string
  default = "10.0.0.0/16"
}

variable "aks_subnet_prefix" {
  type    = string
  default = "10.0.0.0/20"
}

variable "postgres_subnet_prefix" {
  type    = string
  default = "10.0.16.0/24"
}

variable "private_endpoints_subnet_prefix" {
  type    = string
  default = "10.0.17.0/24"
}

# --- AKS ---

variable "kubernetes_version" {
  type    = string
  default = null
}

variable "system_node_vm_size" {
  type    = string
  default = "Standard_D2s_v4"
}

variable "system_node_count" {
  type    = number
  default = 1
}

variable "workload_node_vm_size" {
  type    = string
  default = "Standard_D2s_v4"
}

variable "workload_node_min_count" {
  type    = number
  default = 1
}

variable "workload_node_max_count" {
  type    = number
  default = 2
}

# --- PostgreSQL ---

variable "postgres_sku_name" {
  type    = string
  default = "B_Standard_B1ms"
}

variable "postgres_storage_mb" {
  type    = number
  default = 32768
}

variable "postgres_database_name" {
  type    = string
  default = "shoppulse"
}

variable "postgres_admin_username" {
  type    = string
  default = "shoppulse"
}

# --- Redis ---

variable "redis_sku_name" {
  description = "Azure Managed Redis SKU (Balanced_B0 is smallest dev tier)"
  type        = string
  default     = "Balanced_B0"
}

# --- ACR ---

variable "acr_sku" {
  description = "ACR SKU — Premium required for private endpoints"
  type        = string
  default     = "Premium"
}

variable "acr_public_network_access_enabled" {
  description = "Temporarily true when pushing images from outside the VNet, e.g. a laptop or a GitHub-hosted runner."
  type        = bool
  default     = false
}

variable "acr_allowed_ip_cidrs" {
  description = "Source ranges allowed while ACR public access is on. Empty = any address."
  type        = list(string)
  default     = []
}

# --- Service Bus ---

variable "servicebus_sku" {
  type    = string
  default = "Standard"
}

variable "servicebus_queue_names" {
  type    = list(string)
  default = ["sales-events"]
}

# --- Key Vault laptop bootstrap ---

variable "key_vault_public_network_access_enabled" {
  description = "Temporarily true when applying from a laptop outside the VNet so secrets can be written."
  type        = bool
  default     = false
}

variable "key_vault_deployer_ip_cidrs" {
  description = "Optional override. Empty = auto-detect public IP via api.ipify.org when public KV access is enabled."
  type        = list(string)
  default     = []
}

# --- Kubernetes ---

variable "k8s_namespace" {
  type    = string
  default = "shoppulse"
}

variable "keda_service_account_name" {
  type    = string
  default = "keda-servicebus"
}

variable "worker_service_account_name" {
  type    = string
  default = "worker"
}

variable "api_service_account_name" {
  type    = string
  default = "api"
}
