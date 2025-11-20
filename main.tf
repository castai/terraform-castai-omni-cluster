locals {
  omni_namespace         = "castai-omni"
  omni_agent_release     = "omni-agent"
  omni_agent_chart       = "omni-agent"
  castai_helm_repository = "https://castai.github.io/helm-charts"
}

# OCI Cloud Resources (created first to provide attributes to edge location)
module "liqo" {
  source = "./modules/gke"

  namespace             = local.omni_namespace
  liqo_chart_version    = var.liqo_chart_version
  cluster_name          = var.cluster_name
  cluster_region        = var.cluster_region
  cluster_zone          = var.cluster_zone
  api_server_address    = var.api_server_address
  pod_cidr              = var.pod_cidr
  service_cidr          = var.service_cidr
  reserved_subnet_cidrs = var.reserved_subnet_cidrs
}

# Wait for Liqo network resources to be ready before proceeding
resource "null_resource" "wait_for_liqo_network" {
  provisioner "local-exec" {
    command = <<-EOT
      set -e

      echo "Waiting for Liqo networks.ipam.liqo.io CRD to be established..."
      kubectl wait --for condition=established --timeout=300s crd/networks.ipam.liqo.io

      echo "Waiting for external CIDR network resource to be created..."
      timeout=300
      elapsed=0
      interval=5

      while [ $elapsed -lt $timeout ]; do
        CIDR=$(kubectl get networks.ipam.liqo.io -n ${local.omni_namespace} \
          -l ipam.liqo.io/network-type=external-cidr \
          -o jsonpath='{.items[0].status.cidr}' 2>/dev/null || echo "")

        if [ -n "$CIDR" ]; then
          echo "External CIDR network resource is ready: $CIDR"
          exit 0
        fi

        echo "Waiting for external CIDR to be populated... ($elapsed/$timeout seconds)"
        sleep $interval
        elapsed=$((elapsed + interval))
      done

      echo "Timeout waiting for external CIDR network resource"
      exit 1
    EOT
  }

  depends_on = [module.liqo]
}

# Extract the external CIDR value from Liqo network resource
data "external" "liqo_external_cidr" {
  program = ["bash", "-c", <<-EOT
    CIDR=$(kubectl get networks.ipam.liqo.io -n ${local.omni_namespace} \
      -l ipam.liqo.io/network-type=external-cidr \
      -o jsonpath='{.items[0].status.cidr}' 2>/dev/null)

    if [ -z "$CIDR" ]; then
      echo '{"cidr":""}'
    else
      echo "{\"cidr\":\"$CIDR\"}"
    fi
  EOT
  ]

  depends_on = [null_resource.wait_for_liqo_network]
}

# Enabling CAST AI Omni functionality for a given cluster
resource "castai_omni_cluster" "this" {
  cluster_id      = var.cluster_id
  organization_id = var.organization_id

  depends_on = [null_resource.wait_for_liqo_network]
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
      value = data.external.liqo_external_cidr.result.cidr
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
