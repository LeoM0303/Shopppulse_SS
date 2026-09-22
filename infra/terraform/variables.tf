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

variable "enable_ingress" {
  description = "true = ingress-nginx and a TLS certificate, so the cluster has one public entry point. Ignored when enable_aks=false."
  type        = bool
  default     = true
}

variable "enable_monitoring" {
  description = "true = Log Analytics, Container Insights, Application Insights, alerts and diagnostic settings."
  type        = bool
  default     = true
}

variable "enable_storage" {
  description = "true = blob account for report snapshots with a lifecycle policy. false = skip storage."
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

variable "postgres_backup_retention_days" {
  description = "How far back a point-in-time restore can go, 7 to 35 days"
  type        = number
  default     = 7
}

variable "postgres_geo_redundant_backup_enabled" {
  description = "Copy backups to the paired region. Can only be set at creation time."
  type        = bool
  default     = false
}

variable "postgres_high_availability_enabled" {
  description = "Zone-redundant HA with an automatic failover standby. Needs a General Purpose or Memory Optimized SKU, so it stays off in dev."
  type        = bool
  default     = false
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

# --- Ingress ---

variable "ingress_nginx_chart_version" {
  description = "Pinned ingress-nginx chart version, so a re-apply cannot silently upgrade the controller"
  type        = string
  default     = "4.15.1"
}

variable "ingress_replica_count" {
  description = "Controller replicas. Two in prod so a node drain does not drop all traffic."
  type        = number
  default     = 1
}

variable "ingress_hostname" {
  description = "Host the Ingress answers on and the name in the self-signed certificate. Replace with a real domain plus cert-manager when there is DNS."
  type        = string
  default     = "shoppulse.local"
}

# --- Monitoring ---

variable "log_retention_days" {
  description = "Log Analytics retention in days (30 is the free minimum)"
  type        = number
  default     = 30
}

variable "log_daily_quota_gb" {
  description = "Ingestion cap in GB per day, which keeps a log storm from becoming a bill. -1 removes the cap."
  type        = number
  default     = 1
}

variable "app_insights_sampling_percentage" {
  description = "Share of application telemetry that is kept"
  type        = number
  default     = 100
}

variable "alert_email" {
  description = "Address that receives alerts. null = action group with no receivers."
  type        = string
  default     = null
  nullable    = true
}

# --- Report storage ---

variable "storage_replication_type" {
  description = "LRS for dev, ZRS or GZRS when snapshots must survive a zone or region failure"
  type        = string
  default     = "LRS"
}

variable "reports_container_name" {
  description = "Blob container that holds dashboard snapshots"
  type        = string
  default     = "reports"
}

variable "storage_public_network_access_enabled" {
  description = "Temporarily true when applying from outside the VNet, because containers are created over the blob data plane."
  type        = bool
  default     = false
}

variable "storage_deployer_ip_cidrs" {
  description = "Optional override. Empty = auto-detect the public IP while storage public access is enabled."
  type        = list(string)
  default     = []
}

variable "storage_tier_to_cool_after_days" {
  description = "Days after the last write before a snapshot moves to the cool tier"
  type        = number
  default     = 30
}

variable "storage_tier_to_archive_after_days" {
  description = "Days after the last write before a snapshot moves to the archive tier"
  type        = number
  default     = 90
}

variable "storage_delete_after_days" {
  description = "Days after the last write before a snapshot is deleted"
  type        = number
  default     = 365
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
