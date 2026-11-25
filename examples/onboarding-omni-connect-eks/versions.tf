terraform {
  required_version = ">= 1.10"

  required_providers {
    castai = {
      source  = "castai/castai"
      version = ">= 8.39.1"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.17, < 4.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.35.0"
    }
  }
}

provider "castai" {
  api_token = var.castai_api_token
}
