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
