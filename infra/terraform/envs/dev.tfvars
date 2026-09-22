# Development environment — the sizing the project actually runs on.
#
#   terraform init -backend-config=backend.hcl   # key = shoppulse/dev.tfstate
#   terraform apply -var-file=envs/dev.tfvars

location     = "polandcentral"
environment  = "dev"
project_name = "shoppulse"

tags = {
  team = "platform"
  env  = "dev"
}

# Smallest sizes that still run the whole stack, for an Azure for Students subscription.
system_node_vm_size     = "Standard_D2s_v4"
system_node_count       = 1
workload_node_vm_size   = "Standard_D2s_v4"
workload_node_min_count = 1
workload_node_max_count = 2

postgres_sku_name = "B_Standard_B1ms"
redis_sku_name    = "Balanced_B0"
acr_sku           = "Premium"
servicebus_sku    = "Standard"

# Burstable SKUs cannot run zone-redundant HA, so dev relies on point-in-time
# restore alone. Prod uses General Purpose and turns HA on.
postgres_high_availability_enabled = false
postgres_backup_retention_days     = 7

# No public DNS for dev, so the certificate is self-signed for this name and
# clients reach it with curl --resolve or a hosts entry.
ingress_hostname      = "shoppulse.local"
ingress_replica_count = 1

# Observability. The daily cap matters more than retention on a student subscription:
# ingestion is what costs money, and 1 GB/day is far more than this stack produces.
log_retention_days = 30
log_daily_quota_gb = 1
# alert_email = "you@example.com"

# Report snapshots. LRS is enough for dev, and the tiering steps are short so the
# lifecycle policy can actually be observed instead of taking a year to do anything.
storage_replication_type           = "LRS"
storage_tier_to_cool_after_days    = 7
storage_tier_to_archive_after_days = 30
storage_delete_after_days          = 90
