locals {
  pools_cidrs = concat(
    ["10.0.0.0/8", "192.168.0.0/16", "172.16.0.0/12"],
    var.service_cidr == "34.118.224.0/20" ? ["34.118.224.0/20"] : [],
  )

  liqo_yaml_values = {
    liqo = {
      enabled = true
      apiServer = {
        address = var.api_server_address
      }
      discovery = {
        config = {
          clusterID = var.cluster_name
        }
      }
      ipam = merge(
        {
          podCIDRs        = var.pod_cidrs
          serviceCIDR     = var.service_cidr
          pools           = var.ipam_pools != null ? var.ipam_pools : local.pools_cidrs
          reservedSubnets = var.reserved_subnet_cidrs
        },
        var.ipam_external_cidr != null ? { externalCIDR = var.ipam_external_cidr } : {},
        var.ipam_internal_cidr != null ? { internalCIDR = var.ipam_internal_cidr } : {}
      )
      telemetry = {
        enabled = false
      }
    }
  }
}
