locals {
  pools_cidrs = ["10.0.0.0/8", "192.168.0.0/16", "172.16.0.0/12", var.service_cidr]
  provider    = "eks"

  liqo_yaml_values = {
    liqo = {
      enabled = true
      apiServer = {
        address = var.api_server_address
      }
      discovery = {
        config = {
          clusterID = var.cluster_name
          clusterLabels = {
            "liqo.io/provider"              = local.provider
            "topology.kubernetes.io/region" = var.cluster_region
          }
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
      virtualKubelet = {
        extra = {
          args = ["--certificate-type=aws"]
        }
      }
      networking = {
        fabric = {
          config = {
            fullMasquerade = true
          }
        }
        gatewayTemplates = {
          server = {
            service = {
              annotations = {
                "service.beta.kubernetes.io/aws-load-balancer-type" = "nlb"
              }
            }
          }
        }
      }
    }
  }
}
