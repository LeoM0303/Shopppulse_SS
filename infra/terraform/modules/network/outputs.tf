output "resource_group" {
  description = "Resource group object"
  value = {
    name     = azurerm_resource_group.this.name
    location = azurerm_resource_group.this.location
    id       = azurerm_resource_group.this.id
  }
}

output "vnet_id" {
  description = "Virtual network ID"
  value       = azurerm_virtual_network.this.id
}

output "aks_subnet_id" {
  description = "AKS subnet ID"
  value       = azurerm_subnet.aks.id
}

output "postgres_subnet_id" {
  description = "PostgreSQL delegated subnet ID"
  value       = azurerm_subnet.postgres.id
}

output "private_endpoints_subnet_id" {
  description = "Private endpoints subnet ID"
  value       = azurerm_subnet.private_endpoints.id
}

output "network_security_group_ids" {
  description = "NSG IDs per subnet, keyed by subnet name"
  value = {
    aks               = azurerm_network_security_group.aks.id
    postgres          = azurerm_network_security_group.postgres.id
    private_endpoints = azurerm_network_security_group.private_endpoints.id
    ops               = azurerm_network_security_group.ops.id
  }
}

output "ops_vnet_id" {
  description = "Peered ops VNet, reserved for a jumpbox or a self-hosted runner"
  value       = azurerm_virtual_network.ops.id
}
