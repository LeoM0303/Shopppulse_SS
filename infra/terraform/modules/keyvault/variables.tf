variable "name_prefix" {
  type = string
}

variable "location" {
  type = string
}

variable "tags" {
  type = map(string)
}

variable "resource_group" {
  type = object({
    name     = string
    location = string
    id       = string
  })
}

variable "tenant_id" {
  type = string
}

variable "vnet_id" {
  type = string
}

variable "private_endpoint_subnet_id" {
  type = string
}

variable "identity_principal_ids" {
  description = "Map of workload name to principal ID for Key Vault Secrets User RBAC"
  type        = map(string)
  default     = {}
}

variable "public_network_access_enabled" {
  description = "false in production. true only when Terraform runs outside the VNet and must write secrets."
  type        = bool
  default     = false
}

variable "deployer_ip_cidrs" {
  description = "Public IP CIDRs allowed during temporary public KV access (e.g. [\"1.2.3.4/32\"])."
  type        = list(string)
  default     = []
}
