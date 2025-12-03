locals {
  pools_cidrs = ["10.0.0.0/8", "192.168.0.0/16", "172.16.0.0/12", var.service_cidr]

  basic_set_values = [
    {
      name  = "tag"
      value = var.image_tag
    },
    {
      name  = "apiServer.address"
      value = var.api_server_address
    },
    {
      name  = "discovery.config.clusterID"
      value = var.cluster_name
    },
    {
      name  = "discovery.config.clusterLabels.liqo\\.io/provider"
      value = "aks"
    },
    {
      name  = "discovery.config.clusterLabels.topology\\.kubernetes\\.io/region"
      value = var.cluster_region
    },
    {
      name  = "ipam.podCIDR"
      value = var.pod_cidr
    },
    {
      name  = "ipam.serviceCIDR"
      value = var.service_cidr
    },
    {
      name  = "ipam.serviceCIDR"
      value = var.service_cidr
    },
    {
      name  = "telemetry.enabled"
      value = "false"
    }
  ]

  pools_set_values = [
    for idx, cidr in local.pools_cidrs : {
      name  = "ipam.pools[${idx}]"
      value = cidr
    }
  ]

  all_set_values = concat(
    local.basic_set_values,
    local.pools_set_values,
  )
}
