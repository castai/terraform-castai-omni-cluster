output "cluster_id" {
  description = "CAST AI cluster ID registered with NATIVE"
  value       = module.castai_omni_cluster.cluster_id
}

output "omni_connect_release" {
  description = "The direct omni-connect Helm release, or null in GitOps mode"
  value       = module.castai_omni_cluster.omni_connect_release
}

output "omni_connect_enabled" {
  description = "Whether omni-connect is enabled"
  value       = module.castai_omni_cluster.omni_connect_enabled
}
