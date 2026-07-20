variable "name_prefix" {
  type = string
}

variable "location" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "resource_group_name" {
  type = string
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

variable "public_network_access_enabled" {
  description = "Must be false for production. Set true only when Terraform runs outside the VNet and needs to write secrets."
  type        = bool
  default     = false
}

variable "deployer_ip_cidrs" {
  description = "Optional public IP CIDRs allowed to reach Key Vault data plane during bootstrap (e.g. [\"1.2.3.4/32\"]). Ignored when public access is disabled."
  type        = list(string)
  default     = []
}
