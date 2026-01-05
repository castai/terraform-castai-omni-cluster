locals {
  pools_cidrs = ["10.0.0.0/8", "192.168.0.0/16", "172.16.0.0/12", var.service_cidr]

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
      ipam = {
        podCIDR     = var.pod_cidr
        serviceCIDR = var.service_cidr
        pools       = local.pools_cidrs
      }
      telemetry = {
        enabled = false
      }
      networking = {
        fabric = {
          config = {
            gatewayMasqueradeBypass = true
          }
        }
      }
      virtualKubelet = {
        virtualNode = {
          extra = {
            labels = {
              "kubernetes.azure.com/managed" = "false"
            }
          }
        }
      }
    }
  }
}
