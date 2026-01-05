locals {
  # GKE-specific Liqo configuration
  liqo_yaml_values = {
    liqo = {
      ipam = {
        reservedSubnets = var.reserved_subnet_cidrs
      }
    }
  }
}
