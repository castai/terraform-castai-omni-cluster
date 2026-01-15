# CAST AI Omni Cluster Terraform Module

This Terraform module enables CAST AI Omni functionality for a Kubernetes cluster. CAST AI Omni allows clusters to manage edge locations across multiple cloud providers and regions, enabling distributed infrastructure management with Liqo for multi-cluster networking.

## Features

- Enables CAST AI Omni functionality for existing clusters
- **Support for GKE, EKS, and AKS**
- Installs and configures Liqo for multi-cluster networking with cloud-specific optimizations
- Deploys CAST AI Omni Agent for cluster management
- **GitOps Support**: Optional `skip_helm` parameter to manage Helm releases via GitOps tools (ArgoCD, Flux, etc.)
- Automatic extraction of network configuration from clusters (including external CIDR from Liqo)
- Support for both zonal and regional GKE clusters
- Automatic synchronization with Liqo IPAM for external CIDR allocation
- Cloud-specific configurations:
  - **GKE:** Uses default Liqo network fabric settings
  - **EKS:** Configures AWS Network Load Balancer (NLB) and full masquerade for pod traffic
  - **AKS:** Configures Azure-specific settings

## Prerequisites

- An existing Kubernetes cluster onboarded to CAST AI
- CAST AI API credentials
- `kubectl` configured with access to your Kubernetes cluster
- Terraform >= 1.10
- CAST AI Terraform provider >= 8.4.0
- Helm provider >= 3.1.1
- Kubernetes provider >= 2.35.0
- Null provider >= 3.2.4
- External provider >= 2.3.5
- Google provider >= 4.0 (for GKE clusters)
- AWS provider >= 6.23.0 (for EKS clusters)
- AzureRM provider >= 3.0 (for AKS clusters)

## What This Module Installs

This module creates the necessary Kubernetes resources for CAST AI Omni:

1. **Kubernetes Namespace** (`castai-omni`) - Dedicated namespace for CAST AI Omni components
2. **Kubernetes Secret** - Contains the CAST AI API token for agent authentication
3. **CAST AI Omni Cluster Resource** - Enables Omni functionality in CAST AI
4. **CAST AI Omni Agent Helm Chart** (optional, skippable with `skip_helm = true`) - Manages cluster connectivity and operations
5. **ConfigMap with Helm Values** (created when `skip_helm = true`) - Provides Helm values for GitOps-based deployment

**Note**: When `skip_helm = true`, the module creates only the namespace, secret, ConfigMap, and CAST AI Omni cluster resource, allowing you to manage the Helm chart installation via GitOps tools like ArgoCD or Flux.

## Usage

### Complete GKE Example

```hcl
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
  cluster_zone     = local.is_zonal_cluster ? var.gke_cluster_location : ""
}

# Get subnet details to retrieve the IP CIDR range
data "google_compute_subnetwork" "gke_subnet" {
  project = var.gke_project_id
  name    = local.subnet_name
  region  = local.cluster_region
}

module "castai-omni-cluster" {
  source = "../.."

  k8s_provider    = "gke"  # Specify cloud provider: "gke", "eks", or "aks"
  api_url         = var.castai_api_url
  api_token       = var.castai_api_token
  organization_id = var.organization_id
  cluster_id      = var.cluster_id
  cluster_name    = var.gke_cluster_name
  cluster_region  = local.cluster_region
  cluster_zone    = local.cluster_zone

  api_server_address    = "https://${data.google_container_cluster.gke.endpoint}"
  pod_cidr              = data.google_container_cluster.gke.cluster_ipv4_cidr
  service_cidr          = data.google_container_cluster.gke.services_ipv4_cidr
  reserved_subnet_cidrs = [data.google_compute_subnetwork.gke_subnet.ip_cidr_range]
}

module "castai_omni_edge_location_gcp" {
  source = "castai/omni-edge-location-gcp/castai"

  cluster_id      = var.cluster_id
  organization_id = var.organization_id

  region = "europe-west4"

  depends_on = [module.castai-omni-cluster]
}
```

### Complete EKS Example

```hcl
data "aws_eks_cluster" "eks" {
  name = var.eks_cluster_name
}

data "aws_vpc" "eks_vpc" {
  id = data.aws_eks_cluster.eks.vpc_config[0].vpc_id
}

data "aws_subnets" "eks_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.eks_vpc.id]
  }
}

data "aws_subnet" "eks_subnet" {
  for_each = toset(data.aws_subnets.eks_subnets.ids)
  id       = each.value
}

locals {
  subnet_cidrs = [for s in data.aws_subnet.eks_subnet : s.cidr_block]
}

module "castai_omni_cluster" {
  source = "castai/omni-cluster/castai"

  k8s_provider    = "eks"  # Specify cloud provider: "gke", "eks", or "aks"
  api_url         = var.castai_api_url
  api_token       = var.castai_api_token
  organization_id = var.organization_id
  cluster_id      = var.cluster_id
  cluster_name    = var.eks_cluster_name
  cluster_region  = var.eks_cluster_region

  api_server_address    = data.aws_eks_cluster.eks.endpoint
  pod_cidr              = data.aws_eks_cluster.eks.kubernetes_network_config[0].service_ipv4_cidr
  service_cidr          = data.aws_eks_cluster.eks.kubernetes_network_config[0].service_ipv4_cidr
  reserved_subnet_cidrs = local.subnet_cidrs
}
```

### Complete AKS Example

```hcl
data "azurerm_kubernetes_cluster" "aks" {
  name                = var.aks_cluster_name
  resource_group_name = var.aks_resource_group
}

data "azurerm_virtual_network" "aks_vnet" {
  name                = var.aks_vnet_name
  resource_group_name = var.aks_vnet_resource_group
}

module "castai_omni_cluster" {
  source = "castai/omni-cluster/castai"

  k8s_provider    = "aks"  # Specify cloud provider: "gke", "eks", or "aks"
  api_url         = var.castai_api_url
  api_token       = var.castai_api_token
  organization_id = var.organization_id
  cluster_id      = var.cluster_id
  cluster_name    = var.aks_cluster_name
  cluster_region  = data.azurerm_kubernetes_cluster.aks.location

  api_server_address    = "https://${data.azurerm_kubernetes_cluster.aks.fqdn}"
  pod_cidr              = data.azurerm_kubernetes_cluster.aks.network_profile[0].pod_cidr
  service_cidr          = data.azurerm_kubernetes_cluster.aks.network_profile[0].service_cidr
  reserved_subnet_cidrs = data.azurerm_virtual_network.aks_vnet.address_space
}
```

### GitOps Example (with skip_helm)

When using GitOps tools like ArgoCD or Flux, you can skip the Helm chart installation by Terraform and manage it via your GitOps workflow:

```hcl
module "castai_omni_cluster" {
  source = "castai/omni-cluster/castai"

  k8s_provider    = "gke"
  api_url         = var.castai_api_url
  api_token       = var.castai_api_token
  organization_id = var.organization_id
  cluster_id      = var.cluster_id
  cluster_name    = var.cluster_name
  cluster_region  = var.cluster_region

  api_server_address    = var.api_server_address
  pod_cidr              = var.pod_cidr
  service_cidr          = var.service_cidr
  reserved_subnet_cidrs = var.reserved_subnet_cidrs

  # Skip Helm chart installation - manage via GitOps instead
  skip_helm = true
}
```

When `skip_helm = true`, the module creates a ConfigMap named `castai-omni-helm-values` in the `castai-omni` namespace containing:
- `liqo.version`: The Liqo image tag to use
- `omni-agent.repository`: CAST AI Helm repository URL
- `omni-agent.chart`: CAST AI Omni Agent chart name
- `values.yaml`: Complete Helm values YAML for the CAST AI Omni Agent chart

You can then reference this ConfigMap in your GitOps tools (ArgoCD, Flux, etc.) to install the Helm chart with the correct values.

### Provider Configuration

#### GKE Provider Configuration

```hcl
terraform {
  required_version = ">= 1.10"

  required_providers {
    castai = {
      source  = "castai/castai"
      version = ">= 8.4.0"
    }
    google = {
      source  = "hashicorp/google"
      version = ">= 4.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.35.0"
    }
  }
}

provider "google" {
  project = var.gke_project_id
}

provider "helm" {
  kubernetes = {
    host                   = "https://${data.google_container_cluster.gke.endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(data.google_container_cluster.gke.master_auth.0.cluster_ca_certificate)
  }
}

provider "kubernetes" {
  host                   = "https://${data.google_container_cluster.gke.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(data.google_container_cluster.gke.master_auth.0.cluster_ca_certificate)
}

provider "castai" {
  api_token = var.castai_api_token
  api_url   = var.castai_api_url
}
```

#### EKS Provider Configuration

```hcl
terraform {
  required_version = ">= 1.10"

  required_providers {
    castai = {
      source  = "castai/castai"
      version = ">= 8.4.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.23.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 3.1.1"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.35.0"
    }
  }
}

provider "aws" {
  region = var.eks_cluster_region
}

provider "helm" {
  kubernetes = {
    host                   = data.aws_eks_cluster.eks.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks.certificate_authority[0].data)
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "eks",
        "get-token",
        "--cluster-name",
        data.aws_eks_cluster.eks.name,
        "--region",
        var.eks_cluster_region
      ]
    }
  }
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.eks.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks.certificate_authority[0].data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      data.aws_eks_cluster.eks.name,
      "--region",
      var.eks_cluster_region
    ]
  }
}

provider "castai" {
  api_token = var.castai_api_token
  api_url   = var.castai_api_url
}
```

#### AKS Provider Configuration

```hcl
terraform {
  required_version = ">= 1.10"

  required_providers {
    castai = {
      source  = "castai/castai"
      version = ">= 8.4.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.35.0"
    }
  }
}

provider "azurerm" {
  subscription_id = var.azure_subscription_id
  features {}
}

provider "helm" {
  kubernetes = {
    host                   = data.azurerm_kubernetes_cluster.aks.kube_config[0].host
    client_certificate     = base64decode(data.azurerm_kubernetes_cluster.aks.kube_config[0].client_certificate)
    client_key             = base64decode(data.azurerm_kubernetes_cluster.aks.kube_config[0].client_key)
    cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.aks.kube_config[0].cluster_ca_certificate)
  }
}

provider "kubernetes" {
  host                   = data.azurerm_kubernetes_cluster.aks.kube_config[0].host
  client_certificate     = base64decode(data.azurerm_kubernetes_cluster.aks.kube_config[0].client_certificate)
  client_key             = base64decode(data.azurerm_kubernetes_cluster.aks.kube_config[0].client_key)
  cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.aks.kube_config[0].cluster_ca_certificate)
}

provider "castai" {
  api_token = var.castai_api_token
  api_url   = var.castai_api_url
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| k8s_provider | Kubernetes cloud provider (gke, eks, aks) | `string` | - | yes |
| api_token | CAST AI API token for authentication | `string` | - | yes |
| organization_id | CAST AI organization ID | `string` | - | yes |
| cluster_id | CAST AI cluster ID | `string` | - | yes |
| cluster_name | Cluster name | `string` | - | yes |
| cluster_region | Kubernetes cluster region | `string` | - | yes |
| cluster_zone | Kubernetes cluster zone (optional for EKS) | `string` | `""` | no |
| api_server_address | Kubernetes API server address | `string` | - | yes |
| pod_cidr | Pod CIDR for network configuration | `string` | - | yes |
| service_cidr | Service CIDR for network configuration | `string` | - | yes |
| reserved_subnet_cidrs | List of reserved subnet CIDRs | `list(string)` | `[]` | no |
| api_url | CAST AI API URL | `string` | `"https://api.cast.ai"` | no |
| omni_agent_chart_version | OMNI agent Helm chart version | `string` | `"v1.1.8"` | no |
| skip_helm | Skip installing Helm charts (for GitOps workflows) | `bool` | `false` | no |

## Outputs

| Name | Description                            |
|------|----------------------------------------|
| organization_id | Organization ID of the Omni-enabled cluster    |
| cluster_id | Cluster ID of the Omni-enabled cluster |

## Network Configuration

The module automatically extracts network configuration from your cluster:

### GKE Clusters
- **Subnet CIDR**: Retrieved from the cluster's subnetwork
- **Pod CIDR**: Retrieved from `cluster_ipv4_cidr`
- **Service CIDR**: Retrieved from `services_ipv4_cidr`
- **External CIDR**: Automatically extracted from Liqo network resources after IPAM initialization
- **Region/Zone**: Automatically determined from cluster location

### EKS Clusters
- **Subnet CIDRs**: Retrieved from all VPC subnets
- **Pod CIDR**: Retrieved from `kubernetes_network_config`
- **Service CIDR**: Retrieved from `kubernetes_network_config`
- **External CIDR**: Automatically extracted from Liqo network resources after IPAM initialization
- **Region**: From cluster configuration

### AKS Clusters
- **VNet Address Space**: Retrieved from the Azure Virtual Network
- **Pod CIDR**: Retrieved from `network_profile`
- **Service CIDR**: Retrieved from `network_profile`
- **External CIDR**: Automatically extracted from Liqo network resources after IPAM initialization
- **Region**: From cluster location

## Liqo Configuration

The module includes cloud-specific submodules for optimal Liqo configuration:

### GKE Configuration
- Installs Liqo for multi-cluster networking
- Configures IPAM with pod, service, and reserved subnet CIDRs
- Sets up topology labels for GKE region and zone
- Enables virtual node capabilities for edge locations
- Uses Liqo chart's default configurations for network fabric settings

### EKS Configuration
- Installs Liqo with AWS-optimized settings
- Configures IPAM with pod, service, and reserved subnet CIDRs
- Sets up topology labels for EKS region
- Enables full masquerade for pod traffic (required for EKS networking)
- Configures AWS Network Load Balancer (NLB) for gateway service
- Enables virtual node capabilities for edge locations

### AKS Configuration
- Installs Liqo with Azure-optimized settings
- Configures IPAM with pod, service, and reserved subnet CIDRs from VNet
- Sets up topology labels for AKS location
- Enables virtual node capabilities for edge locations

## Installation Order and Dependencies

The module ensures proper installation order by:

1. **Namespace and Secret Creation** - Creates the `castai-omni` namespace and API token secret
2. **CAST AI Omni Cluster** - Enables Omni functionality in CAST AI
3. **CAST AI Omni Agent Installation** (when `skip_helm = false`, default):
   - Installs the CAST AI Omni Agent Helm chart with the configured values
   - The agent manages cluster connectivity and operations

**When `skip_helm = true` (GitOps mode)**:
- Step 3 is skipped, and instead a ConfigMap (`castai-omni-helm-values`) is created
- The ConfigMap contains all necessary Helm values for manual or GitOps-based deployment
- You are responsible for installing the CAST AI Omni Agent Helm chart using your preferred deployment method

## Examples

Complete working examples are available for all supported cloud providers:
- **GKE**: [examples/onboarding-with-existing-gke-cluster](./examples/onboarding-with-existing-gke-cluster)
- **EKS**: [examples/onboarding-with-existing-eks-cluster](./examples/onboarding-with-existing-eks-cluster)
- **AKS**: [examples/onboarding-with-existing-aks-cluster](./examples/onboarding-with-existing-aks-cluster)

## Related Modules

- [terraform-castai-omni-cluster](https://github.com/castai/terraform-castai-omni-cluster) - Create and manage Omni clusters
- [terraform-castai-omni-edge-location-gcp](https://github.com/castai/terraform-castai-omni-edge-location-gcp) - Create and manage GCP edge locations for Omni clusters
- [terraform-castai-omni-edge-location-aws](https://github.com/castai/terraform-castai-omni-edge-location-aws) - Create and manage AWS edge locations for Omni clusters
- [terraform-castai-omni-edge-location-oci](https://github.com/castai/terraform-castai-omni-edge-location-oci) - Create and manage OCI edge locations for Omni clusters
- [terraform-castai-gke-cluster](https://github.com/castai/terraform-castai-gke-cluster) - Onboard GKE clusters to CAST AI
- [terraform-castai-eks-cluster](https://github.com/castai/terraform-castai-eks-cluster) - Onboard EKS clusters to CAST AI
- [terraform-castai-aks-cluster](https://github.com/castai/terraform-castai-aks) - Onboard AKS clusters to CAST AI

## License

MIT
<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.10 |
| <a name="requirement_castai"></a> [castai](#requirement\_castai) | >= 8.4.0 |
| <a name="requirement_external"></a> [external](#requirement\_external) | >= 2.3.5 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 3.1.1 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.35.0 |
| <a name="requirement_null"></a> [null](#requirement\_null) | >= 3.2.4 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_castai"></a> [castai](#provider\_castai) | 8.8.0 |
| <a name="provider_helm"></a> [helm](#provider\_helm) | 3.1.1 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | 3.0.1 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_liqo_helm_values_aks"></a> [liqo\_helm\_values\_aks](#module\_liqo\_helm\_values\_aks) | ./modules/aks | n/a |
| <a name="module_liqo_helm_values_eks"></a> [liqo\_helm\_values\_eks](#module\_liqo\_helm\_values\_eks) | ./modules/eks | n/a |
| <a name="module_liqo_helm_values_gke"></a> [liqo\_helm\_values\_gke](#module\_liqo\_helm\_values\_gke) | ./modules/gke | n/a |

## Resources

| Name | Type |
|------|------|
| [castai_omni_cluster.this](https://registry.terraform.io/providers/castai/castai/latest/docs/resources/omni_cluster) | resource |
| [helm_release.omni_agent](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_config_map_v1.helm_values](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/config_map_v1) | resource |
| [kubernetes_namespace_v1.omni](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace_v1) | resource |
| [kubernetes_secret_v1.api_token](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret_v1) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_api_server_address"></a> [api\_server\_address](#input\_api\_server\_address) | K8s API server address | `string` | n/a | yes |
| <a name="input_api_token"></a> [api\_token](#input\_api\_token) | CAST AI API token (key) for authentication | `string` | n/a | yes |
| <a name="input_api_url"></a> [api\_url](#input\_api\_url) | CAST AI API URL | `string` | `"https://api.cast.ai"` | no |
| <a name="input_cluster_id"></a> [cluster\_id](#input\_cluster\_id) | CAST AI cluster ID to enable Omni functionality for | `string` | n/a | yes |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | CAST AI cluster name | `string` | n/a | yes |
| <a name="input_cluster_region"></a> [cluster\_region](#input\_cluster\_region) | Not used. This variable is kept for backwards compatibility, will be removed in the future. | `string` | `""` | no |
| <a name="input_cluster_zone"></a> [cluster\_zone](#input\_cluster\_zone) | Not used. This variable is kept for backwards compatibility, will be removed in the future. | `string` | `""` | no |
| <a name="input_k8s_provider"></a> [k8s\_provider](#input\_k8s\_provider) | Kubernetes cloud provider (gke, eks, aks) | `string` | n/a | yes |
| <a name="input_omni_agent_chart_version"></a> [omni\_agent\_chart\_version](#input\_omni\_agent\_chart\_version) | OMNI agent helm chart version | `string` | `"1.1.11"` | no |
| <a name="input_organization_id"></a> [organization\_id](#input\_organization\_id) | CAST AI organization ID | `string` | n/a | yes |
| <a name="input_pod_cidr"></a> [pod\_cidr](#input\_pod\_cidr) | Pod CIDR for network configuration | `string` | n/a | yes |
| <a name="input_reserved_subnet_cidrs"></a> [reserved\_subnet\_cidrs](#input\_reserved\_subnet\_cidrs) | List of reserved subnet CIDR's (relevant for GKE) | `list(string)` | `[]` | no |
| <a name="input_service_cidr"></a> [service\_cidr](#input\_service\_cidr) | Service CIDR for network configuration | `string` | n/a | yes |
| <a name="input_skip_helm"></a> [skip\_helm](#input\_skip\_helm) | Skip installing any helm release; allows managing helm releases using GitOps | `bool` | `false` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cluster_id"></a> [cluster\_id](#output\_cluster\_id) | Cluster ID of the Omni-enabled cluster |
| <a name="output_organization_id"></a> [organization\_id](#output\_organization\_id) | Organization ID of the Omni-enabled cluster |
<!-- END_TF_DOCS -->