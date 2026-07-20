variable "subscription_id" {
  description = "Optional. Prefer ARM_SUBSCRIPTION_ID from az account show."
  type        = string
  default     = null
  nullable    = true
}

variable "environment" {
  description = "Environment name used in resource naming"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name used as naming prefix"
  type        = string
  default     = "shoppulse"
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}

# --- Existing network (defaults match bootstrap-network naming) ---

variable "resource_group_name" {
  description = "Existing RG. Default: {project}-{environment}-rg"
  type        = string
  default     = null
  nullable    = true
}

variable "vnet_name" {
  description = "Existing VNet. Default: {project}-{environment}-vnet"
  type        = string
  default     = null
  nullable    = true
}

variable "private_endpoints_subnet_name" {
  description = "Subnet used for private endpoints"
  type        = string
  default     = "private-endpoints"
}

variable "postgres_subnet_name" {
  description = "Subnet delegated to PostgreSQL Flexible Server"
  type        = string
  default     = "postgres"
}

# --- PostgreSQL ---

variable "postgres_admin_username" {
  description = "PostgreSQL administrator username"
  type        = string
  default     = "shoppulse"
}

variable "postgres_database_name" {
  description = "Application database name"
  type        = string
  default     = "shoppulse"
}

# --- Key Vault bootstrap (laptop apply outside VNet) ---

variable "key_vault_public_network_access_enabled" {
  description = <<-EOT
    Task requires false. For first apply from a laptop, pass -var=true;
    deployer IP is auto-detected unless key_vault_deployer_ip_cidrs is set.
  EOT
  type        = bool
  default     = false
}

variable "key_vault_deployer_ip_cidrs" {
  description = "Optional override. Empty = auto-detect public IP via api.ipify.org when public KV access is enabled."
  type        = list(string)
  default     = []
}
