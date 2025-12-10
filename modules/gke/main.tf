locals {
  pools_cidrs = ["10.0.0.0/8", "192.168.0.0/16", "172.16.0.0/12", var.service_cidr]
  provider    = "gke"

  liqo_yaml_values = {
    liqo = {
      enabled = true
      tag     = var.image_tag
      apiServer = {
        address = var.api_server_address
      }
      discovery = {
        config = {
          clusterID = var.cluster_name
          clusterLabels = merge(
            {
              "liqo.io/provider"              = local.provider
              "topology.kubernetes.io/region" = var.cluster_region
            },
            var.cluster_zone != "" ? {
              "topology.kubernetes.io/zone" = var.cluster_zone
            } : {}
          )
        }
      }
      ipam = {
        podCIDR         = var.pod_cidr
        serviceCIDR     = var.service_cidr
        pools           = local.pools_cidrs
        reservedSubnets = var.reserved_subnet_cidrs
      }
      telemetry = {
        enabled = false
      }
    }
  }
}
