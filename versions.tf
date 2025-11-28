terraform {
  required_version = ">= 1.10"

  required_providers {
    castai = {
      source  = "castai/castai"
      version = ">= 8.4.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 3.1.1"
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
