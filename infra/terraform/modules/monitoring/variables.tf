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
  description = "Resource group the workspace and alerts live in"
  type = object({
    name     = string
    location = string
    id       = string
  })
}

variable "retention_in_days" {
  description = "How long Log Analytics keeps ingested data"
  type        = number
  default     = 30
}

variable "daily_quota_gb" {
  description = "Ingestion cap in GB per day. -1 disables the cap."
  type        = number
  default     = 1
}

variable "sampling_percentage" {
  description = "Application Insights sampling. Lower it in prod if telemetry volume gets expensive."
  type        = number
  default     = 100
}

variable "alert_email" {
  description = "Address that receives alerts. null = create the action group without receivers."
  type        = string
  default     = null
  nullable    = true
}

variable "k8s_namespace" {
  description = "Namespace the log alerts look at"
  type        = string
}

variable "aks_enabled" {
  description = "false = skip the cluster and container log alerts. Kept separate from aks_cluster_id because count cannot depend on a value that is only known after apply."
  type        = bool
  default     = true
}

variable "aks_cluster_id" {
  description = "AKS cluster the cluster alerts are scoped to"
  type        = string
  default     = null
  nullable    = true
}

variable "postgres_server_id" {
  description = "PostgreSQL flexible server to alert on"
  type        = string
}

variable "diagnostic_target_ids" {
  description = "Resources whose platform logs and metrics are shipped to the workspace, keyed by a short name"
  type        = map(string)
  default     = {}
}

variable "metrics_only_targets" {
  description = "Keys of diagnostic_target_ids that expose metrics but no log categories"
  type        = list(string)
  default     = []
}

variable "logs_only_targets" {
  description = "Keys of diagnostic_target_ids that expose logs but no metrics"
  type        = list(string)
  default     = []
}
