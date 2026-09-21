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
