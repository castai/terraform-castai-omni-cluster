output "organization_id" {
  description = "Organization ID of the Omni-enabled cluster"
  value       = castai_omni_cluster.this.organization_id
}

output "cluster_id" {
  description = "Cluster ID of the Omni-enabled cluster"
  value       = castai_omni_cluster.this.id
}
