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
      value = "eks"
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
      name  = "telemetry.enabled"
      value = "false"
    },
    {
      name  = "virtualKubelet.extra.args"
      value = "{--certificate-type=aws}"
    }
  ]

  pools_set_values = [
    for idx, cidr in local.pools_cidrs : {
      name  = "ipam.pools[${idx}]"
      value = cidr
    }
  ]

  eks_specific_set_values = [
    {
      name  = "networking.fabric.config.fullMasquerade"
      value = "true"
    },
    {
      name  = "networking.gatewayTemplates.server.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-type"
      value = "nlb"
    }
  ]

  all_set_values = concat(
    local.basic_set_values,
    local.pools_set_values,
    local.eks_specific_set_values
  )
}
