terraform {
  required_version = ">= 1.11"

  required_providers {
    castai = {
      source  = "castai/castai"
      version = ">= 8.2.0"
    }
    google = {
      source  = "hashicorp/google"
      version = ">= 4.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.0"
    }
  }
}

provider "google" {
  project = var.gke_project_id
}

provider "aws" {
  region = "eu-west-1"
}

provider "helm" {
  kubernetes = {
    host                   = "https://${data.google_container_cluster.gke.endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(data.google_container_cluster.gke.master_auth.0.cluster_ca_certificate)
  }
}

provider "castai" {
  api_token = var.castai_api_token
  api_url   = var.castai_api_url
}
