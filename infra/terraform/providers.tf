terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.35"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17"
    }
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = var.environment == "dev"
      recover_soft_deleted_key_vaults = true
    }
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }

  subscription_id = var.subscription_id
}

provider "kubernetes" {
  host                   = try(module.aks.kube_admin_config[0].host, "")
  client_certificate     = try(base64decode(module.aks.kube_admin_config[0].client_certificate), "")
  client_key             = try(base64decode(module.aks.kube_admin_config[0].client_key), "")
  cluster_ca_certificate = try(base64decode(module.aks.kube_admin_config[0].cluster_ca_certificate), "")
}

provider "helm" {
  kubernetes {
    host                   = try(module.aks.kube_admin_config[0].host, "")
    client_certificate     = try(base64decode(module.aks.kube_admin_config[0].client_certificate), "")
    client_key             = try(base64decode(module.aks.kube_admin_config[0].client_key), "")
    cluster_ca_certificate = try(base64decode(module.aks.kube_admin_config[0].cluster_ca_certificate), "")
  }
}
