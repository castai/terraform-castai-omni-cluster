# Configure data sources and providers required for CAST AI connection.
data "azurerm_client_config" "current" {}

# Register the AKS cluster with CAST AI and create the Azure AD application +
# role assignments. The module outputs cluster_id and organization_id which
# feed the omni-cluster module below.
module "castai_aks" {
  source  = "castai/aks/castai"
  version = "~> 11.0"

  aks_cluster_name           = azurerm_kubernetes_cluster.aks.name
  aks_cluster_region         = azurerm_resource_group.aks.location
  subscription_id            = data.azurerm_client_config.current.subscription_id
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  resource_group             = azurerm_kubernetes_cluster.aks.resource_group_name
  node_resource_group        = azurerm_kubernetes_cluster.aks.node_resource_group
  default_node_configuration = "default"

  node_configurations = {
    default = {
      subnets = [azurerm_subnet.aks.id]
      tags    = var.tags
    }
  }

  castai_api_token       = var.castai_api_token
  api_url                = var.castai_api_url
  kvisor_grpc_addr       = var.kvisor_grpc_url
  wait_for_cluster_ready = true

  depends_on = [azurerm_kubernetes_cluster.aks]
}

module "castai_omni_cluster" {
  source = "../.."

  k8s_provider    = "aks"
  api_url         = var.castai_api_url
  kvisor_grpc_url = var.kvisor_grpc_url
  api_token       = var.castai_api_token
  organization_id = module.castai_aks.organization_id
  cluster_id      = module.castai_aks.cluster_id
  cluster_name    = var.cluster_name

  api_server_address = "https://${azurerm_kubernetes_cluster.aks.fqdn}"
  pod_cidrs          = [azurerm_kubernetes_cluster.aks.network_profile[0].pod_cidr]
  service_cidr       = azurerm_kubernetes_cluster.aks.network_profile[0].service_cidr

  reserved_subnet_cidrs = azurerm_virtual_network.aks.address_space

  skip_helm = var.skip_helm

  depends_on = [module.castai_aks]
}

# Custom (non-aws/gcp/oci) edge location created directly via the castai
# provider's castai_edge_location resource using the custom block.
resource "castai_edge_location" "custom_location" {
  name               = "linode-location"
  cluster_id         = module.castai_omni_cluster.cluster_id
  organization_id    = module.castai_omni_cluster.organization_id
  region             = var.custom_edge_location_region
  description        = "Custom edge location onboarded by Terraform"
  control_plane_mode = "SHARED"

  control_plane = {
    ha = true
  }

  zones = [
    {
      id   = var.custom_edge_location_region
      name = var.custom_edge_location_region
    }
  ]

  custom = {}

  depends_on = [module.castai_omni_cluster]
}
