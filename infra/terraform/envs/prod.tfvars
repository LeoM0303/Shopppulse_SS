# Production environment. Declarative only so far — this has never been applied, and the
# sizing below costs real money, well beyond the student subscription.
#
#   terraform init -backend-config=backend.hcl   # key = shoppulse/prod.tfstate
#   terraform apply -var-file=envs/prod.tfvars
#
# The state key is what separates the two environments: same code, separate state files.

location     = "polandcentral"
environment  = "prod"
project_name = "shoppulse"

tags = {
  team = "platform"
  env  = "prod"
}

# Two workload nodes minimum so a single node going away does not take the app down.
system_node_vm_size     = "Standard_D2s_v4"
system_node_count       = 2
workload_node_vm_size   = "Standard_D4s_v4"
workload_node_min_count = 2
workload_node_max_count = 4

# General Purpose instead of Burstable: predictable CPU and room for more storage.
postgres_sku_name   = "GP_Standard_D2s_v3"
postgres_storage_mb = 65536

redis_sku_name = "Balanced_B1"
acr_sku        = "Premium"
servicebus_sku = "Standard"

# Longer retention for post-incident analysis, no ingestion cap so alerts never go
# blind mid-incident, and sampling to keep the telemetry bill predictable.
log_retention_days               = 90
log_daily_quota_gb               = -1
app_insights_sampling_percentage = 30
# alert_email = "oncall@example.com"

# Zone-redundant snapshots, and a full year in the archive tier before deletion.
storage_replication_type           = "ZRS"
storage_tier_to_cool_after_days    = 30
storage_tier_to_archive_after_days = 90
storage_delete_after_days          = 730
