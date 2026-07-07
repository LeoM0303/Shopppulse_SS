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
