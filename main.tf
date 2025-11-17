# CAST AI Omni Cluster Resource
# This resource enables CAST AI Omni functionality for a cluster,
# allowing it to manage edge locations and distributed infrastructure.
resource "castai_omni_cluster" "this" {
  cluster_id      = var.cluster_id
  organization_id = var.organization_id
}
