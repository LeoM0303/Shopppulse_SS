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
