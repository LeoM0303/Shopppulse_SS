# Optional bootstrap: creates the RG + VNet + subnets that the data-layer stack
# expects to already exist. Run once, then apply ../ (terraform-data root).
#
#   $env:ARM_SUBSCRIPTION_ID = (az account show --query id -o tsv)
#   cd bootstrap-network
#   terraform init && terraform apply

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
  # Uses ARM_SUBSCRIPTION_ID env or az CLI default when null
  subscription_id = var.subscription_id
}

variable "subscription_id" {
  description = "Optional. Prefer: $env:ARM_SUBSCRIPTION_ID = (az account show --query id -o tsv)"
  type        = string
  default     = null
  nullable    = true
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "polandcentral"
}

variable "project_name" {
  type    = string
  default = "shoppulse"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "vnet_address_space" {
  type    = string
  default = "10.0.0.0/16"
}

variable "postgres_subnet_prefix" {
  type    = string
  default = "10.0.16.0/24"
}

variable "private_endpoints_subnet_prefix" {
  type    = string
  default = "10.0.17.0/24"
}

variable "tags" {
  type    = map(string)
  default = {}
}

locals {
  name_prefix         = "${var.project_name}-${var.environment}"
  resource_group_name = "${local.name_prefix}-rg"
  vnet_name           = "${local.name_prefix}-vnet"
  common_tags = merge(
    {
      project     = var.project_name
      environment = var.environment
      managed_by  = "terraform"
    },
    var.tags
  )
}

resource "azurerm_resource_group" "this" {
  name     = local.resource_group_name
  location = var.location
  tags     = local.common_tags
}

resource "azurerm_virtual_network" "this" {
  name                = local.vnet_name
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = [var.vnet_address_space]
  tags                = local.common_tags
}

resource "azurerm_subnet" "postgres" {
  name                 = "postgres"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.postgres_subnet_prefix]

  delegation {
    name = "postgres-delegation"

    service_delegation {
      name = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}

resource "azurerm_subnet" "private_endpoints" {
  name                 = "private-endpoints"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.private_endpoints_subnet_prefix]
}

output "resource_group_name" {
  value = azurerm_resource_group.this.name
}

output "vnet_name" {
  value = azurerm_virtual_network.this.name
}

output "location" {
  value = azurerm_resource_group.this.location
}

output "postgres_subnet_id" {
  value = azurerm_subnet.postgres.id
}

output "private_endpoints_subnet_id" {
  value = azurerm_subnet.private_endpoints.id
}
