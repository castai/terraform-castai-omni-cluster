output "organization_id" {
  description = "Organization ID of the Omni-enabled cluster"
  value       = castai_omni_cluster.this.organization_id
}

output "cluster_id" {
  description = "Cluster ID of the Omni-enabled cluster"
  value       = castai_omni_cluster.this.id
}

output "omni_connect_enabled" {
  description = "Whether the optional Omni-Connect control plane is enabled"
  value       = var.install_omni_connect
}

output "omni_connect_release" {
  description = "Direct Helm release metadata for Omni-Connect, or null in GitOps/disabled mode"
  value       = var.install_omni_connect && !var.skip_helm ? module.omni_connect[0].release : null
}
