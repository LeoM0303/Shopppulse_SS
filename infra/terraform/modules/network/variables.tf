variable "name_prefix" {
  type = string
}

variable "location" {
  type = string
}

variable "tags" {
  type = map(string)
}

variable "vnet_address_space" {
  type = string
}

variable "aks_subnet_prefix" {
  type = string
}

variable "postgres_subnet_prefix" {
  type = string
}

variable "private_endpoints_subnet_prefix" {
  type = string
}

variable "ops_vnet_address_space" {
  description = "Address space of the ops VNet that is peered to the app VNet. Must not overlap."
  type        = string
  default     = "10.1.0.0/16"
}

variable "ops_subnet_prefix" {
  description = "Subnet inside the ops VNet, reserved for a jumpbox or a self-hosted runner"
  type        = string
  default     = "10.1.0.0/24"
}
