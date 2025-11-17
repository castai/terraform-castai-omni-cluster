# data "google_project" "current" {}

# data "google_client_config" "default" {}

# data "google_container_cluster" "gke" {
#   name     = var.gke_cluster_name
#   location = var.gke_cluster_region
#   project  = data.google_project.current.project_id
# }

# data "aws_region" "current" {}

# =============================================================================
# Onboard cluster to CAST AI
# =============================================================================

# module "castai-gke-iam" {
#   source  = "castai/gke-iam/castai"
#   version = "~> 0.5"
#
#   project_id       = data.google_project.current.project_id
#   gke_cluster_name = data.google_container_cluster.gke.name
# }

# module "castai-gke-cluster" {
#   source  = "castai/gke-cluster/castai"
#   version = "~> 9"
#
#   api_url          = var.castai_api_url
#   castai_api_token = var.castai_api_token
#
#   project_id           = data.google_project.current.project_id
#   gke_cluster_name     = data.google_container_cluster.gke.name
#   gke_cluster_location = data.google_container_cluster.gke.location
#   gke_credentials      = module.castai-gke-iam.private_key
#
#   wait_for_cluster_ready          = true
#   default_node_configuration_name = "default"
#
#   node_configurations = {
#     default = {
#       subnets = [data.google_container_cluster.gke.subnetwork]
#     }
#   }
#
#   // TODO: enable omni
# }

module "castai-omni-cluster" {
  source = "../.."

  cluster_id      = var.cluster_id
  organization_id = var.organization_id
}
