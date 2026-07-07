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

variable "sku_name" {
  description = "Azure Managed Redis SKU (e.g. Balanced_B0 for dev)"
  type        = string
}
