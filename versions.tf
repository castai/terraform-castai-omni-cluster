terraform {
  required_version = ">= 1.11"

  required_providers {
    castai = {
      source  = "castai/castai"
      version = ">= 8.1.1"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 3.0.0"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.0"
    }
  }
}
