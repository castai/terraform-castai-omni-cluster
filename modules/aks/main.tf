locals {
  # AKS-specific Liqo configuration
  liqo_yaml_values = {
    liqo = {
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
