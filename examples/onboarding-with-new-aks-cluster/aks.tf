# Azure Kubernetes Service cluster.
# AKS ships with a default `managed-csi` storage class (Azure Disk CSI),
# so unlike EKS we don't need to create a custom one.

resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.cluster_name
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name
  dns_prefix          = var.cluster_name

  # Let Azure pick the default supported Kubernetes version for the region.
  # Set var.kubernetes_version to a specific version (e.g. "1.31") only if you
  # have verified it's supported without LTS: `az aks get-versions -l <region>`
  kubernetes_version = var.kubernetes_version

  identity {
    type = "SystemAssigned"
  }

  default_node_pool {
    name           = "system"
    node_count     = var.aks_node_count
    vm_size        = var.aks_node_vm_size
    vnet_subnet_id = azurerm_subnet.aks.id
  }

  node_provisioning_profile {
    default_node_pools = "None"
    mode               = "Manual"
  }

  network_profile {
    network_plugin = "kubenet"
    pod_cidr       = "10.244.0.0/16"
    service_cidr   = "10.245.0.0/16"
    dns_service_ip = "10.245.0.10"
  }

  tags = var.tags
}

output "aks_cluster_name" {
  description = "Name of the AKS cluster."
  value       = azurerm_kubernetes_cluster.aks.name
}

output "aks_resource_group" {
  description = "Resource group containing the AKS cluster."
  value       = azurerm_kubernetes_cluster.aks.resource_group_name
}

output "aks_cluster_fqdn" {
  description = "FQDN of the AKS API server."
  value       = azurerm_kubernetes_cluster.aks.fqdn
}
