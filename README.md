# CAST AI Omni Cluster Terraform Module

This Terraform module enables CAST AI Omni functionality for a Kubernetes cluster. CAST AI Omni allows clusters to manage edge locations across multiple cloud providers and regions, enabling distributed infrastructure management with Liqo for multi-cluster networking.

## Features

- Enables CAST AI Omni functionality for existing clusters
- Installs and configures Liqo for multi-cluster networking
- Deploys CAST AI Omni Agent for cluster management
- Automatic extraction of network configuration from GKE clusters
- Support for both zonal and regional GKE clusters
- Configurable IPAM and network settings

## Prerequisites

- An existing Kubernetes cluster onboarded to CAST AI
- CAST AI API credentials
- Terraform >= 1.11
- CAST AI Terraform provider >= 8.1.1
- Helm provider >= 3.0.0
- Google provider >= 4.0 (for GKE clusters)

## What This Module Installs

1. **Liqo** - Multi-cluster networking capability for connecting edge locations
2. **CAST AI Omni Cluster Resource** - Enables Omni functionality in CAST AI
3. **CAST AI Omni Agent** - Manages cluster connectivity and operations

## Usage

### Complete GKE Example

```hcl
data "google_container_cluster" "gke" {
  project  = var.gke_project_id
  location = var.gke_cluster_location
  name     = var.gke_cluster_name
}

locals {
  # Extract subnet and region/zone information
  subnet_name      = element(reverse(split("/", data.google_container_cluster.gke.subnetwork)), 0)
  is_zonal_cluster = length(regexall("^.*-[a-z]$", var.gke_cluster_location)) > 0
  cluster_region   = local.is_zonal_cluster ? regex("^(.*)-[a-z]$", var.gke_cluster_location)[0] : var.gke_cluster_location
  cluster_zone     = local.is_zonal_cluster ? var.gke_cluster_location : ""
}

data "google_compute_subnetwork" "gke_subnet" {
  project = var.gke_project_id
  name    = local.subnet_name
  region  = local.cluster_region
}

module "castai-omni-cluster" {
  source = "github.com/castai/terraform-castai-omni-cluster"

  # CAST AI Configuration
  api_url         = "https://api.cast.ai"
  api_token       = var.castai_api_token
  organization_id = var.organization_id
  cluster_id      = var.cluster_id
  cluster_name    = var.gke_cluster_name

  # Cluster Location
  cluster_region = local.cluster_region
  cluster_zone   = local.cluster_zone

  # Kubernetes Configuration
  api_server_address = "https://${data.google_container_cluster.gke.endpoint}"

  # Network Configuration
  external_cidr         = var.external_cidr
  pod_cidr              = data.google_container_cluster.gke.cluster_ipv4_cidr
  service_cidr          = data.google_container_cluster.gke.services_ipv4_cidr
  reserved_subnet_cidrs = [data.google_compute_subnetwork.gke_subnet.ip_cidr_range]

  # Liqo Configuration
  liqo_chart_version = "v1.0.1-5"
}

# Create edge location
module "castai_gcp_edge_location" {
  source = "github.com/castai/terraform-castai-omni-edge-location"

  cluster_id      = var.cluster_id
  organization_id = var.organization_id

  gcp = {
    region = "europe-west4"
  }

  depends_on = [module.castai-omni-cluster]
}
```

### Required Providers

```hcl
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
    google = {
      source  = "hashicorp/google"
      version = ">= 4.0"
    }
  }
}

provider "castai" {
  api_token = var.castai_api_token
  api_url   = "https://api.cast.ai"
}

provider "helm" {
  kubernetes {
    host                   = "https://${data.google_container_cluster.gke.endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(data.google_container_cluster.gke.master_auth[0].cluster_ca_certificate)
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| api_token | CAST AI API token for authentication | `string` | - | yes |
| organization_id | CAST AI organization ID | `string` | - | yes |
| cluster_id | CAST AI cluster ID | `string` | - | yes |
| cluster_name | Cluster name | `string` | - | yes |
| cluster_region | Kubernetes cluster region | `string` | - | yes |
| cluster_zone | Kubernetes cluster zone | `string` | - | yes |
| api_server_address | Kubernetes API server address | `string` | - | yes |
| external_cidr | External CIDR for IPAM configuration | `string` | - | yes |
| pod_cidr | Pod CIDR for network configuration | `string` | - | yes |
| service_cidr | Service CIDR for network configuration | `string` | - | yes |
| reserved_subnet_cidrs | List of reserved subnet CIDRs | `list(string)` | - | yes |
| api_url | CAST AI API URL | `string` | `"https://api.cast.ai"` | no |
| liqo_chart_version | Liqo Helm chart version | `string` | `"v1.0.1-5"` | no |

## Outputs

| Name | Description |
|------|-------------|
| cluster_id | ID of the Omni-enabled cluster |
| organization_id | Organization ID of the Omni cluster |
| id | ID of the castai_omni_cluster resource |

## Network Configuration

The module automatically extracts network configuration from your GKE cluster:

- **Subnet CIDR**: Retrieved from the cluster's subnetwork
- **Pod CIDR**: Retrieved from `cluster_ipv4_cidr`
- **Service CIDR**: Retrieved from `services_ipv4_cidr`
- **Region/Zone**: Automatically determined from cluster location

## Liqo Configuration

The module includes a GKE-specific submodule that:
- Installs Liqo for multi-cluster networking
- Configures IPAM with pod, service, and reserved subnet CIDRs
- Sets up topology labels for GKE region and zone
- Enables virtual node capabilities for edge locations

## Examples

See the [examples/onboarding-with-existing-gke-cluster](./examples/onboarding-with-existing-gke-cluster) directory for a complete working example.

## Related Modules

- [terraform-castai-omni-edge-location](https://github.com/castai/terraform-castai-omni-edge-location) - Create and manage edge locations for Omni clusters
- [terraform-castai-gke-cluster](https://github.com/castai/gke-cluster) - Onboard GKE clusters to CAST AI

## License

MIT