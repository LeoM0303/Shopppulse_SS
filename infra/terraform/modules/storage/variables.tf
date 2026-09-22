variable "name_prefix" {
  description = "Prefix for resource names, {project}-{environment}"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "tags" {
  description = "Tags applied to every resource in this module"
  type        = map(string)
  default     = {}
}

variable "resource_group" {
  description = "Resource group the account lives in"
  type = object({
    name     = string
    location = string
    id       = string
  })
}

variable "vnet_id" {
  description = "VNet the private DNS zone is linked to"
  type        = string
}

variable "private_endpoint_subnet_id" {
  description = "Subnet that holds the blob private endpoint"
  type        = string
}

variable "replication_type" {
  description = "LRS for dev, ZRS or GZRS when the data has to survive a zone or region failure"
  type        = string
  default     = "LRS"
}

variable "container_names" {
  description = "Blob containers to create"
  type        = list(string)
  default     = ["reports"]
}

variable "public_network_access_enabled" {
  description = "Temporarily true when applying from a laptop or a hosted runner, because containers are created over the data plane."
  type        = bool
  default     = false
}

variable "deployer_ip_cidrs" {
  description = "Source ranges allowed while public access is on. Azure rejects /31 and /32, so only the address part is used."
  type        = list(string)
  default     = []
}

variable "writer_principal_ids" {
  description = "Principals that get Storage Blob Data Contributor, keyed by a short name"
  type        = map(string)
  default     = {}
}

variable "reader_principal_ids" {
  description = "Principals that get Storage Blob Data Reader, keyed by a short name"
  type        = map(string)
  default     = {}
}

variable "delete_retention_days" {
  description = "Soft delete window for blobs, containers, snapshots and versions"
  type        = number
  default     = 30
}

variable "tier_to_cool_after_days" {
  description = "Move blobs to the cool tier this many days after the last write"
  type        = number
  default     = 30
}

variable "tier_to_archive_after_days" {
  description = "Move blobs to the archive tier this many days after the last write"
  type        = number
  default     = 90
}

variable "delete_after_days" {
  description = "Delete blobs this many days after the last write"
  type        = number
  default     = 365
}
