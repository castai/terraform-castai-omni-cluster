output "liqo_release_name" {
  description = "Name of the liqo Helm release"
  value       = helm_release.liqo.name
}

output "liqo_namespace" {
  description = "Namespace where liqo is installed"
  value       = helm_release.liqo.namespace
}

output "liqo_version" {
  description = "Version of the liqo Helm chart installed"
  value       = helm_release.liqo.version
}

output "liqo_status" {
  description = "Status of the liqo Helm release"
  value       = helm_release.liqo.status
}