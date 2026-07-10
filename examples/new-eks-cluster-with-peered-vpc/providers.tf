terraform {
  required_version = ">= 1.10"

  required_providers {
    castai = {
      source  = "castai/castai"
      version = ">= 8.48.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.54.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 3.2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 3.2.1"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.3.0"
    }
    external = {
      source  = "hashicorp/external"
      version = ">= 2.4.0"
    }
    google = {
      source  = "hashicorp/google"
      version = ">= 7.39.0"
    }
    oci = {
      source  = "oracle/oci"
      version = ">= 8.22.0"
    }
  }
}

provider "aws" {
  alias  = "eu_south_2"
  region = "eu-south-2"
}

provider "aws" {
  region = var.cluster_region
}

provider "helm" {
  kubernetes = {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "eks",
        "get-token",
        "--cluster-name",
        module.eks.cluster_name,
        "--region",
        var.cluster_region
      ]
    }
  }
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      module.eks.cluster_name,
      "--region",
      var.cluster_region
    ]
  }
}

provider "castai" {
  api_token = var.castai_api_token
  api_url   = var.castai_api_url
}

provider "google" {
  project = var.google_project_id
}

provider "oci" {
  region = var.oci_region
}

provider "oci" {
  alias  = "home"
  region = var.oci_home_region
}
