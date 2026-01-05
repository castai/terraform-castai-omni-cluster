# List of subnets to be reserved so that liqo does not use them. 
# It is good practice to reserve at least the subnet CIDR range used by the cluster nodes.
check "reserved_cidrs_required_for_gke" {
  assert {
    condition     = var.k8s_provider != "gke" || (var.reserved_subnet_cidrs != null && length(var.reserved_subnet_cidrs) > 0)
    error_message = "'reserved_subnet_cidrs' must be provided for GKE cluster"
  }
}

# GKE-specific Liqo Helm chart configuration
module "liqo_helm_values_gke" {
  count  = var.k8s_provider == "gke" ? 1 : 0
  source = "./modules/gke"

  api_server_address    = var.api_server_address
  pod_cidr              = var.pod_cidr
  service_cidr          = var.service_cidr
  reserved_subnet_cidrs = var.reserved_subnet_cidrs
}

# EKS-specific Liqo Helm chart configuration
module "liqo_helm_values_eks" {
  count  = var.k8s_provider == "eks" ? 1 : 0
  source = "./modules/eks"

  api_server_address = var.api_server_address
  pod_cidr           = var.pod_cidr
  service_cidr       = var.service_cidr
}

# AKS-specific Liqo Helm chart configuration
module "liqo_helm_values_aks" {
  count  = var.k8s_provider == "aks" ? 1 : 0
  source = "./modules/aks"

  api_server_address = var.api_server_address
  pod_cidr           = var.pod_cidr
  service_cidr       = var.service_cidr
}

locals {
  omni_namespace          = "castai-omni"
  omni_agent_release      = "castai-omni-agent"
  omni_agent_chart        = "omni-agent"
  castai_helm_repository  = "https://castai.github.io/helm-charts"
  castai_agent_secret_ref = "castai-omni-agent-token"

  # Common pools CIDRs used across all providers
  pools_cidrs = ["10.0.0.0/8", "192.168.0.0/16", "172.16.0.0/12", var.service_cidr]

  # Common Liqo configuration as YAML
  common_liqo_yaml_values = {
    enabled = true
    apiServer = {
      address = var.api_server_address
    }
    discovery = {
      config = {
        clusterID = var.cluster_name
      }
    }
    ipam = {
      podCIDR     = var.pod_cidr
      serviceCIDR = var.service_cidr
      pools       = local.pools_cidrs
    }
    telemetry = {
      enabled = false
    }
  }

  # Select the appropriate yaml_values based on k8s_provider
  liqo_yaml_values = merge(
    { for v in module.liqo_helm_values_gke : "gke" => v.liqo_yaml_values },
    { for v in module.liqo_helm_values_eks : "eks" => v.liqo_yaml_values },
    { for v in module.liqo_helm_values_aks : "aks" => v.liqo_yaml_values },
  )
}

module "liqo_helm_values" {
  source  = "cloudposse/config/yaml//modules/deepmerge"
  version = "0.2.0"
  maps = [
    local.common_liqo_yaml_values,
    local.liqo_yaml_values[var.k8s_provider].liqo,
  ]
}

locals {
  helm_yaml_values = {
    castai = {
      apiUrl          = var.api_url
      apiKeySecretRef = local.castai_agent_secret_ref
      organizationID  = var.organization_id
      clusterID       = var.cluster_id
      clusterName     = var.cluster_name
    }
    liqo = module.liqo_helm_values.merged
  }
}

resource "kubernetes_namespace_v1" "omni" {
  metadata {
    name = local.omni_namespace
  }
}

# Secret with API token for GitOps (when skip_helm = true)
resource "kubernetes_secret_v1" "api_token" {
  metadata {
    name      = local.castai_agent_secret_ref
    namespace = local.omni_namespace
  }

  data = {
    "CASTAI_AGENT_TOKEN" = var.api_token
  }

  depends_on = [kubernetes_namespace_v1.omni]
}

# CAST AI Omni Agent Helm Release
resource "helm_release" "omni_agent" {
  count = var.skip_helm ? 0 : 1

  name             = local.omni_agent_release
  repository       = local.castai_helm_repository
  chart            = local.omni_agent_chart
  version          = var.omni_agent_chart_version
  namespace        = local.omni_namespace
  create_namespace = false
  cleanup_on_fail  = true
  wait             = true

  values = [yamlencode(local.helm_yaml_values)]

  depends_on = [kubernetes_secret_v1.api_token]
}

# Enabling CAST AI Omni functionality for a given cluster
resource "castai_omni_cluster" "this" {
  cluster_id      = var.cluster_id
  organization_id = var.organization_id

  depends_on = [helm_release.omni_agent]
}

# ConfigMap with helm values for GitOps (when skip_helm = true)
resource "kubernetes_config_map_v1" "helm_values" {
  count = var.skip_helm ? 1 : 0

  metadata {
    name      = "castai-omni-helm-values"
    namespace = local.omni_namespace
  }

  data = {
    "omni-agent.repository" = local.castai_helm_repository
    "omni-agent.chart"      = local.omni_agent_chart
    "values.yaml"           = yamlencode(local.helm_yaml_values)
  }

  depends_on = [kubernetes_namespace_v1.omni]
}
