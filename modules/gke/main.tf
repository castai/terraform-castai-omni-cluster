locals {
  liqo_release_name = "omni"
  liqo_chart_repo   = "https://castai.github.io/liqo"
  liqo_chart_name   = "liqo"

  # Format reserved subnet CIDRs as YAML array with proper indentation
  pools_cidrs      = ["10.0.0.0/8", "192.168.0.0/16", "172.16.0.0/12", var.service_cidr]
  pools_cidrs_yaml = length(local.pools_cidrs) > 0 ? join("\n    ", [
    for cidr in local.pools_cidrs : "- ${cidr}"
  ]) : "[]"

  reserved_subnets_yaml = length(var.reserved_subnet_cidrs) > 0 ? join("\n    ", [
    for cidr in var.reserved_subnet_cidrs : "- ${cidr}"
  ]) : "[]"

  # Render the values file with variable substitutions
  liqo_helm_values = templatefile("${path.module}/templates/values.yaml", {
    cluster_name           = var.cluster_name
    liqo_version           = var.liqo_chart_version
    api_server_address     = var.api_server_address
    cluster_region         = var.cluster_region
    cluster_zone           = var.cluster_zone
    pod_cidr               = var.pod_cidr
    service_cidr           = var.service_cidr
    pools_cidrs            = local.pools_cidrs_yaml
    reserved_subnets_cidrs = local.reserved_subnets_yaml
  })
}

# Liqo Helm Release
resource "helm_release" "liqo" {
  name             = local.liqo_release_name
  repository       = local.liqo_chart_repo
  chart            = local.liqo_chart_name
  version          = var.liqo_chart_version
  namespace        = var.namespace
  create_namespace = true
  cleanup_on_fail  = true
  wait             = true

  values = [
    local.liqo_helm_values
  ]
}
