locals {
  pools_cidrs = ["10.0.0.0/8", "192.168.0.0/16", "172.16.0.0/12"]

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
          podCIDR         = var.pod_cidr
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
      networking = {
        fabric = {
          config = {
            fullMasquerade                 = true
            routeConfigurationRulePriority = 400
          }
        }
      }
      virtualKubelet = {
        extra = {
          args = ["--certificate-type=aws"]
        }
      }
    }
  }
}
