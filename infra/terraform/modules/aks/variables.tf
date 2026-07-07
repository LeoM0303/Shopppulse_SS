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

variable "cluster_identity_id" {
  type = string
}

variable "kubelet_identity" {
  type = object({
    id           = string
    client_id    = string
    principal_id = string
  })
}

variable "kubernetes_version" {
  type    = string
  default = null
}

variable "system_node_vm_size" {
  type = string
}

variable "system_node_count" {
  type = number
}

variable "workload_node_vm_size" {
  type = string
}

variable "workload_node_min" {
  type = number
}

variable "workload_node_max" {
  type = number
}

variable "service_cidr" {
  description = "Kubernetes service CIDR (must not overlap with VNet address space)"
  type        = string
  default     = "10.1.0.0/16"
}

variable "dns_service_ip" {
  description = "Kubernetes DNS service IP (must be within service_cidr)"
  type        = string
  default     = "10.1.0.10"
}

variable "pod_cidr" {
  description = "Pod overlay CIDR for Azure CNI overlay mode"
  type        = string
  default     = "10.244.0.0/16"
}
