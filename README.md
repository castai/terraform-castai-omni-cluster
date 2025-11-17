# CAST AI Omni Cluster Terraform Module

This Terraform module enables CAST AI Omni functionality for a Kubernetes cluster. CAST AI Omni allows clusters to manage edge locations across multiple cloud providers and regions, enabling distributed infrastructure management.

## Features

- Enables CAST AI Omni functionality for existing clusters
- Simple configuration with minimal required inputs
- Integrates with CAST AI's edge location management
- Compatible with GKE, EKS, and AKS clusters

## Prerequisites

- An existing Kubernetes cluster onboarded to CAST AI
- CAST AI API credentials configured in your provider
- Terraform >= 1.0
- CAST AI Terraform provider >= 8.1.1

## Usage

### Basic Example

```hcl
module "castai-omni-cluster" {
  source = "github.com/castai/terraform-castai-omni-edge-cluster"

  cluster_id      = "your-cluster-id"
  organization_id = "your-organization-id"
}
```

### Complete Example with GKE

```hcl
# Onboard GKE cluster to CAST AI
module "castai-gke-cluster" {
  source  = "castai/gke-cluster/castai"
  version = "~> 9"

  api_url          = "https://api.cast.ai"
  castai_api_token = var.castai_api_token

  project_id           = "my-gcp-project"
  gke_cluster_name     = "my-cluster"
  gke_cluster_location = "us-central1"

  # ... other configuration
}

# Enable Omni functionality
module "castai-omni-cluster" {
  source = "github.com/castai/terraform-castai-omni-edge-cluster"

  cluster_id      = module.castai-gke-cluster.cluster_id
  organization_id = module.castai-gke-cluster.organization_id
}

# Create edge locations
module "edge-location-us-east" {
  source = "github.com/castai/terraform-castai-omni-edge-location"

  cluster_id      = module.castai-omni-cluster.cluster_id
  organization_id = module.castai-omni-cluster.organization_id

  aws = {
    region = "us-east-1"
  }
}
```

<!-- BEGIN_TF_DOCS -->

<!-- END_TF_DOCS -->

## Related Modules

- [terraform-castai-omni-edge-location](https://github.com/castai/terraform-castai-omni-edge-location) - Create and manage edge locations for Omni clusters
- [terraform-castai-gke-cluster](https://github.com/castai/gke-cluster) - Onboard GKE clusters to CAST AI
- [terraform-castai-eks-cluster](https://github.com/castai/eks-cluster) - Onboard EKS clusters to CAST AI

## License

MIT