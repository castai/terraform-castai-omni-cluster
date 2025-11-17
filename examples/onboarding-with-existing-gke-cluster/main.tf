data "google_client_config" "default" {}

data "google_container_cluster" "gke" {
  project  = var.gke_project_id
  location = var.gke_cluster_location
  name     = var.gke_cluster_name
}

module "castai-omni-cluster" {
  source = "../.."

  organization_id = var.organization_id
  cluster_id      = var.cluster_id
  cluster_name    = var.cluster_name
  api_token       = var.castai_api_token
  api_url         = var.castai_api_url
  external_cidr   = var.external_cidr
  pod_cidr        = data.google_container_cluster.gke.cluster_ipv4_cidr
}
