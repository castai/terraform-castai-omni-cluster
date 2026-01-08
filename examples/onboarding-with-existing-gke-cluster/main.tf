data "google_client_config" "default" {}

data "google_container_cluster" "gke" {
  project  = var.gke_project_id
  location = var.gke_cluster_location
  name     = var.gke_cluster_name
}

locals {
  # The subnetwork can be a full path like "projects/PROJECT/regions/REGION/subnetworks/SUBNET"
  # or just the subnet name
  subnet_name = element(reverse(split("/", data.google_container_cluster.gke.subnetwork)), 0)

  # Determine region from location (if zonal, extract region; if regional, use as-is)
  is_zonal_cluster = length(regexall("^.*-[a-z]$", var.gke_cluster_location)) > 0
  cluster_region   = local.is_zonal_cluster ? regex("^(.*)-[a-z]$", var.gke_cluster_location)[0] : var.gke_cluster_location
}

# Get subnet details to retrieve the IP CIDR range
data "google_compute_subnetwork" "gke_subnet" {
  project = var.gke_project_id
  name    = local.subnet_name
  region  = local.cluster_region
}

module "castai_omni_cluster" {
  source = "../.."

  k8s_provider    = "gke"
  api_url         = var.castai_api_url
  api_token       = var.castai_api_token
  organization_id = var.organization_id
  cluster_id      = var.cluster_id
  cluster_name    = var.gke_cluster_name

  api_server_address    = "https://${data.google_container_cluster.gke.endpoint}"
  pod_cidr              = data.google_container_cluster.gke.cluster_ipv4_cidr
  service_cidr          = data.google_container_cluster.gke.services_ipv4_cidr
  reserved_subnet_cidrs = [data.google_compute_subnetwork.gke_subnet.ip_cidr_range]

  skip_helm = var.skip_helm
}

module "castai_omni_edge_location_gcp" {
  source  = "castai/omni-edge-location-gcp/castai"
  version = "~> 1"

  cluster_id      = module.castai_omni_cluster.cluster_id
  organization_id = module.castai_omni_cluster.organization_id
  region          = "europe-west4"
}
