locals {
  # EKS-specific Liqo configuration
  liqo_yaml_values = {
    liqo = {
      networking = {
        fabric = {
          config = {
            fullMasquerade = true
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
