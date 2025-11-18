locals {
  omni_namespace         = "castai-omni"
  omni_agent_release     = "omni-agent"
  omni_agent_chart       = "omni-agent"
  castai_helm_repository = "https://castai.github.io/helm-charts"
}

# OCI Cloud Resources (created first to provide attributes to edge location)
module "liqo" {
  source = "./modules/gke"

  liqo_chart_version    = var.liqo_chart_version
  cluster_name          = var.cluster_name
  cluster_region        = var.cluster_region
  cluster_zone          = var.cluster_zone
  api_server_address    = var.api_server_address
  pod_cidr              = var.pod_cidr
  service_cidr          = var.service_cidr
  reserved_subnet_cidrs = var.reserved_subnet_cidrs
}

# Enabling CAST AI Omni functionality for a given cluster
resource "castai_omni_cluster" "this" {
  cluster_id      = var.cluster_id
  organization_id = var.organization_id

  depends_on = [module.liqo]
}

# CAST AI Omni Agent Helm Release
resource "helm_release" "omni_agent" {
  name             = local.omni_agent_release
  repository       = local.castai_helm_repository
  chart            = local.omni_agent_chart
  namespace        = local.omni_namespace
  create_namespace = true
  cleanup_on_fail  = true
  wait             = true

  set = [
    {
      name  = "network.externalCIDR"
      value = var.external_cidr
    },
    {
      name  = "network.podCIDR"
      value = var.pod_cidr
    },
    {
      name  = "castai.apiUrl"
      value = var.api_url
    },
    {
      name  = "castai.organizationID"
      value = var.organization_id
    },
    {
      name  = "castai.clusterID"
      value = var.cluster_id
    },
    {
      name  = "castai.clusterName"
      value = var.cluster_name
    }
  ]

  set_sensitive = [
    {
      name  = "castai.apiKey"
      value = var.api_token
    }
  ]

  depends_on = [castai_omni_cluster.this]
}
