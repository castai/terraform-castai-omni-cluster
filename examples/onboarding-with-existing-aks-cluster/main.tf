data "azurerm_kubernetes_cluster" "aks" {
  name                = var.aks_cluster_name
  resource_group_name = var.aks_resource_group
}

module "castai_omni_cluster" {
  source = "../.."

  k8s_provider    = "aks"
  api_url         = var.castai_api_url
  api_token       = var.castai_api_token
  organization_id = var.organization_id
  cluster_id      = var.cluster_id
  cluster_name    = var.aks_cluster_name

  api_server_address = "https://${data.azurerm_kubernetes_cluster.aks.fqdn}"
  pod_cidr           = data.azurerm_kubernetes_cluster.aks.network_profile[0].pod_cidr
  service_cidr       = data.azurerm_kubernetes_cluster.aks.network_profile[0].service_cidr

  skip_helm = var.skip_helm
}

module "castai_omni_edge_location_gcp" {
  source = "github.com/castai/terraform-castai-omni-edge-location-gcp"

  cluster_id      = module.castai_omni_cluster.cluster_id
  organization_id = module.castai_omni_cluster.organization_id
  region          = "europe-west4"
}
