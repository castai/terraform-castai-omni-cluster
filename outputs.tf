output "cluster_id" {
  description = "ID of the Omni-enabled cluster"
  value       = castai_omni_cluster.this.cluster_id
}

output "organization_id" {
  description = "Organization ID of the Omni cluster"
  value       = castai_omni_cluster.this.organization_id
}

output "id" {
  description = "ID of the castai_omni_cluster resource"
  value       = castai_omni_cluster.this.id
}