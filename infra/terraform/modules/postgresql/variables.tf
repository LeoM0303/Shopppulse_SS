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

variable "subnet_id" {
  type = string
}

variable "vnet_id" {
  type = string
}

variable "admin_username" {
  type = string
}

variable "admin_password" {
  type      = string
  sensitive = true
}

variable "database_name" {
  type = string
}

variable "sku_name" {
  type = string
}

variable "storage_mb" {
  type = number
}
