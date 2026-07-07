data "azurerm_client_config" "current" {}

resource "azurerm_kubernetes_cluster" "this" {
  name                = "${var.name_prefix}-aks"
  location            = var.location
  resource_group_name = var.resource_group.name
  dns_prefix          = var.name_prefix
  tags                = var.tags

  kubernetes_version = var.kubernetes_version

  identity {
    type         = "UserAssigned"
    identity_ids = [var.cluster_identity_id]
  }

  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  default_node_pool {
    name                         = "system"
    vm_size                      = var.system_node_vm_size
    vnet_subnet_id               = var.subnet_id
    type                         = "VirtualMachineScaleSets"
    only_critical_addons_enabled = true
    node_count                   = var.system_node_count
    os_disk_size_gb              = 128
    os_sku                       = "AzureLinux"

    upgrade_settings {
      max_surge = "10%"
    }
  }

  kubelet_identity {
    client_id                 = var.kubelet_identity.client_id
    object_id                 = var.kubelet_identity.principal_id
    user_assigned_identity_id = var.kubelet_identity.id
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_policy      = "cilium"
    network_data_plane  = "cilium"
    load_balancer_sku   = "standard"
    outbound_type       = "loadBalancer"
    # Must not overlap with VNet/subnets (10.0.0.0/16)
    service_cidr   = var.service_cidr
    dns_service_ip = var.dns_service_ip
    pod_cidr       = var.pod_cidr
  }

  workload_autoscaler_profile {
    keda_enabled = true
  }

  azure_active_directory_role_based_access_control {
    tenant_id          = data.azurerm_client_config.current.tenant_id
    azure_rbac_enabled = true
  }

  maintenance_window {
    allowed {
      day   = "Sunday"
      hours = [2, 3, 4]
    }
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "workloads" {
  name                  = "workloads"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.this.id
  vm_size               = var.workload_node_vm_size
  vnet_subnet_id        = var.subnet_id
  mode                  = "User"
  os_disk_size_gb       = 128
  os_sku                = "AzureLinux"

  auto_scaling_enabled = true
  min_count            = var.workload_node_min
  max_count            = var.workload_node_max

  node_labels = {
    "workload" = "apps"
  }

  upgrade_settings {
    max_surge = "33%"
  }
}
