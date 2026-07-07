variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "location" {
  description = "Azure region for all resources"
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

# --- Network ---

variable "vnet_address_space" {
  description = "Address space for the virtual network"
  type        = string
  default     = "10.0.0.0/16"
}

variable "aks_subnet_prefix" {
  description = "Address prefix for the AKS subnet"
  type        = string
  default     = "10.0.0.0/20"
}

variable "postgres_subnet_prefix" {
  description = "Address prefix for the PostgreSQL delegated subnet"
  type        = string
  default     = "10.0.16.0/24"
}

variable "private_endpoints_subnet_prefix" {
  description = "Address prefix for private endpoints subnet"
  type        = string
  default     = "10.0.17.0/24"
}

# --- AKS ---

variable "kubernetes_version" {
  description = "Kubernetes version for the AKS cluster"
  type        = string
  default     = null
}

variable "system_node_vm_size" {
  description = "VM size for the system node pool"
  type        = string
  default     = "Standard_D2s_v4"
}

variable "system_node_count" {
  description = "Initial node count for the system node pool"
  type        = number
  default     = 1
}

variable "workload_node_vm_size" {
  description = "VM size for the workload node pool"
  type        = string
  default     = "Standard_D2s_v4"
}

variable "workload_node_min_count" {
  description = "Minimum nodes in the workload node pool"
  type        = number
  default     = 1
}

variable "workload_node_max_count" {
  description = "Maximum nodes in the workload node pool"
  type        = number
  default     = 2
}

# --- PostgreSQL ---

variable "postgres_sku_name" {
  description = "SKU for PostgreSQL Flexible Server"
  type        = string
  default     = "B_Standard_B1ms"
}

variable "postgres_storage_mb" {
  description = "Storage size in MB for PostgreSQL"
  type        = number
  default     = 32768
}

variable "postgres_database_name" {
  description = "Application database name"
  type        = string
  default     = "shoppulse"
}

variable "postgres_admin_username" {
  description = "PostgreSQL administrator username"
  type        = string
  default     = "shoppulse"
}

# --- Redis (Azure Managed Redis — replaces retired Azure Cache for Redis) ---

variable "redis_sku_name" {
  description = "Azure Managed Redis SKU (Balanced_B0 is smallest dev tier)"
  type        = string
  default     = "Balanced_B0"
}

# --- Service Bus ---

variable "servicebus_sku" {
  description = "Service Bus namespace SKU"
  type        = string
  default     = "Standard"
}

variable "servicebus_queue_names" {
  description = "Queue names to create in the Service Bus namespace"
  type        = list(string)
  default     = ["sales-events"]
}

# --- Kubernetes ---

variable "k8s_namespace" {
  description = "Kubernetes namespace for ShopPulse workloads"
  type        = string
  default     = "shoppulse"
}

variable "keda_service_account_name" {
  description = "Service account name used by KEDA Service Bus scaler"
  type        = string
  default     = "keda-servicebus"
}

variable "worker_service_account_name" {
  description = "Service account name for the worker workload"
  type        = string
  default     = "worker"
}

variable "api_service_account_name" {
  description = "Service account name for the API workload"
  type        = string
  default     = "api"
}
