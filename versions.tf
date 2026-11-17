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
    null = {
      source  = "hashicorp/null"
      version = ">= 3.2.4"
    }
    external = {
      source  = "hashicorp/external"
      version = ">= 2.3.5"
    }
  }
}
