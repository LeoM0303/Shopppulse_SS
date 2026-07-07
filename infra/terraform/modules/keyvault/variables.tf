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

variable "identity_principal_ids" {
  description = "Map of workload name to principal ID for Key Vault RBAC"
  type        = map(string)
}
