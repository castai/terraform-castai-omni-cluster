terraform {
  required_version = ">= 1.0"

  required_providers {
    castai = {
      source  = "castai/castai"
      version = ">= 8.1.0"
    }
    # aws = {
    #   source  = "hashicorp/aws"
    #   version = ">= 5.0"
    # }
    # google = {
    #   source  = "hashicorp/google"
    #   version = ">= 4.0"
    # }
    # oci = {
    #   source  = "oracle/oci"
    #   version = "7.4.0"
    # }
  }
}

# provider "aws" {
#   profile = var.aws_profile
# }

# provider "google" {
#   project = var.google_project_id
# }

# provider "oci" {
#   region = var.oci_region
# }

# provider "helm" {
#   kubernetes = {
#     host                   = "https://${data.google_container_cluster.gke.endpoint}"
#     token                  = data.google_client_config.default.access_token
#     cluster_ca_certificate = base64decode(data.google_container_cluster.gke.master_auth.0.cluster_ca_certificate)
#   }
# }

provider "castai" {
  api_token = var.castai_api_token
  api_url   = var.castai_api_url
}
