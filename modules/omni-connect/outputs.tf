output "helm_values" {
  description = "Computed provider-specific values used for both Helm and GitOps deployment"
  value       = local.helm_values
}

output "chart" {
  description = "Chart reference used by this module"
  value       = local.chart
}

output "overrides" {
  description = "User-provided Helm overrides appended after the computed values for GitOps consumers"
  value       = var.omni_connect.helm_values
}

output "values" {
  description = "Rendered values files in the order direct Helm and GitOps consumers must apply them"
  value       = local.values
}

output "release" {
  description = "Helm release created during direct deployment, or null in GitOps mode"
  value = var.skip_helm ? null : {
    name      = helm_release.omni_connect[0].name
    namespace = helm_release.omni_connect[0].namespace
    version   = helm_release.omni_connect[0].version
  }
}
