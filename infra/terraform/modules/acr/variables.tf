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

variable "vnet_id" {
  type = string
}

variable "private_endpoint_subnet_id" {
  type = string
}

variable "sku" {
  description = "ACR SKU — Premium required for private endpoints"
  type        = string
  default     = "Premium"
}

variable "public_network_access_enabled" {
  description = "Open the ACR data plane to the internet — needed to push images from outside the VNet"
  type        = bool
  default     = false
}

variable "allowed_ip_cidrs" {
  description = "Source ranges allowed when public access is on; empty means any address"
  type        = list(string)
  default     = []
}
