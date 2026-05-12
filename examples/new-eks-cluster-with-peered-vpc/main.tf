# Configure Data sources and providers required for CAST AI connection.
data "aws_caller_identity" "current" {}

# Configure EKS cluster connection using CAST AI eks-cluster module.
resource "castai_eks_clusterid" "cluster_id" {
  account_id   = data.aws_caller_identity.current.account_id
  region       = var.cluster_region
  cluster_name = var.cluster_name
}

resource "castai_eks_user_arn" "castai_user_arn" {
  cluster_id = castai_eks_clusterid.cluster_id.id
}

# Create AWS IAM policies and a user to connect to CAST AI.
module "castai_eks_role_iam" {
  source  = "castai/eks-role-iam/castai"
  version = "~> 2.0"

  aws_account_id     = data.aws_caller_identity.current.account_id
  aws_cluster_region = var.cluster_region
  aws_cluster_name   = var.cluster_name
  aws_cluster_vpc_id = module.eks_vpc.vpc_id

  castai_user_arn = castai_eks_user_arn.castai_user_arn.arn

  create_iam_resources_per_cluster = true
}

# CAST AI access entry for nodes to join the cluster.
resource "aws_eks_access_entry" "castai" {
  cluster_name  = module.eks.cluster_name
  principal_arn = module.castai_eks_role_iam.instance_profile_role_arn
  type          = "EC2_LINUX"
}

module "castai_eks_cluster" {
  source                 = "castai/eks-cluster/castai"
  version                = "~> 14.1"
  api_url                = var.castai_api_url
  castai_api_token       = var.castai_api_token
  grpc_url               = var.castai_grpc_url
  wait_for_cluster_ready = true

  aws_account_id     = data.aws_caller_identity.current.account_id
  aws_cluster_region = var.cluster_region
  aws_cluster_name   = module.eks.cluster_name

  aws_assume_role_arn = module.castai_eks_role_iam.role_arn

  default_node_configuration = module.castai_eks_cluster.castai_node_configurations["default"]

  node_configurations = {
    default = {
      subnets = module.eks_vpc.private_subnets
      tags    = var.tags
      security_groups = [
        module.eks.cluster_security_group_id,
        module.eks.node_security_group_id,
        aws_security_group.additional.id,
      ]
      instance_profile_arn = module.castai_eks_role_iam.instance_profile_arn
    }
  }

  depends_on = [
    module.castai_eks_role_iam,
    aws_eks_access_entry.castai,
    kubernetes_storage_class_v1.gp3,
    helm_release.aws_load_balancer_controller,
  ]
}

module "castai_omni_cluster" {
  source = "../.."

  k8s_provider    = "eks"
  api_url         = var.castai_api_url
  kvisor_grpc_url = var.kvisor_grpc_url
  api_token       = var.castai_api_token
  organization_id = var.organization_id
  cluster_id      = castai_eks_clusterid.cluster_id.id
  cluster_name    = var.cluster_name
  cluster_region  = var.cluster_region

  pod_cidr           = module.eks_vpc.vpc_cidr_block
  api_server_address = module.eks.cluster_endpoint
  service_cidr       = module.eks.cluster_service_cidr

  storage_provider      = var.storage_provider
  loadbalancer_provider = var.loadbalancer_provider

  skip_helm = var.skip_helm

  depends_on = [
    module.castai_eks_cluster,
    kubernetes_storage_class_v1.gp3,
    helm_release.aws_load_balancer_controller,
  ]
}

locals {
  edge_location_zones = ["eu-south-2a", "eu-south-2b", "eu-south-2c"]
}

resource "aws_vpc" "edge_location" {
  provider             = aws.eu_south_2
  cidr_block           = "10.2.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.cluster_name}-edge-eu-south-2"
  }
}

# Private subnets for edge location VMs (10.2.0.x–10.2.2.x)
resource "aws_subnet" "edge_location" {
  provider          = aws.eu_south_2
  count             = length(local.edge_location_zones)
  vpc_id            = aws_vpc.edge_location.id
  cidr_block        = cidrsubnet("10.2.0.0/16", 8, count.index)
  availability_zone = local.edge_location_zones[count.index]

  tags = {
    Name = "${var.cluster_name}-edge-eu-south-2-${count.index}"
  }
}

# Public subnet for NAT gateway (10.2.100.0/24)
resource "aws_subnet" "edge_location_public" {
  provider                = aws.eu_south_2
  vpc_id                  = aws_vpc.edge_location.id
  cidr_block              = "10.2.100.0/24"
  availability_zone       = local.edge_location_zones[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.cluster_name}-edge-eu-south-2-public"
  }
}

resource "aws_internet_gateway" "edge_location" {
  provider = aws.eu_south_2
  vpc_id   = aws_vpc.edge_location.id

  tags = {
    Name = "${var.cluster_name}-edge-eu-south-2"
  }
}

resource "aws_eip" "edge_location_nat" {
  provider = aws.eu_south_2
  domain   = "vpc"

  tags = {
    Name = "${var.cluster_name}-edge-eu-south-2-nat"
  }
}

resource "aws_nat_gateway" "edge_location" {
  provider      = aws.eu_south_2
  allocation_id = aws_eip.edge_location_nat.id
  subnet_id     = aws_subnet.edge_location_public.id

  tags = {
    Name = "${var.cluster_name}-edge-eu-south-2"
  }

  depends_on = [aws_internet_gateway.edge_location]
}

# Public route table: IGW for outbound internet
resource "aws_route_table" "edge_location_public" {
  provider = aws.eu_south_2
  vpc_id   = aws_vpc.edge_location.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.edge_location.id
  }

  tags = {
    Name = "${var.cluster_name}-edge-eu-south-2-public"
  }
}

resource "aws_route_table_association" "edge_location_public" {
  provider       = aws.eu_south_2
  subnet_id      = aws_subnet.edge_location_public.id
  route_table_id = aws_route_table.edge_location_public.id
}

# Private route table: NAT gateway for outbound internet
resource "aws_route_table" "edge_location" {
  provider = aws.eu_south_2
  vpc_id   = aws_vpc.edge_location.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.edge_location.id
  }

  tags = {
    Name = "${var.cluster_name}-edge-eu-south-2"
  }
}

resource "aws_route_table_association" "edge_location" {
  provider       = aws.eu_south_2
  count          = length(aws_subnet.edge_location)
  subnet_id      = aws_subnet.edge_location[count.index].id
  route_table_id = aws_route_table.edge_location.id
}

module "castai_omni_edge_location_aws" {
  source  = "castai/omni-edge-location-aws/castai"
  version = "~> 2.1"

  providers = {
    aws = aws.eu_south_2
  }

  cluster_id      = module.castai_omni_cluster.cluster_id
  organization_id = module.castai_omni_cluster.organization_id
  region          = "eu-south-2"
  zones           = local.edge_location_zones
  name            = var.aws_edge_location_name
  vpc_id          = aws_vpc.edge_location.id
  subnet_ids      = aws_subnet.edge_location[*].id
  networking      = {
    tunneled_cidrs = []
  }

  tags = {
    ManagedBy = "terraform"
  }
}

module "castai_omni_edge_location_gcp" {
  source  = "castai/omni-edge-location-gcp/castai"
  version = "~> 2.1"

  cluster_id      = module.castai_omni_cluster.cluster_id
  organization_id = module.castai_omni_cluster.organization_id
  region          = var.gcp_region
  name            = var.gcp_edge_location_name
  networking      = {
    tunneled_cidrs = []
  }
}

# module "castai_oci_edge_location" {
#   source  = "castai/omni-edge-location-oci/castai"
#   version = "~> 2.0"
#
#   providers = {
#     oci      = oci
#     oci.home = oci.home
#   }
#
#   cluster_id      = module.castai_omni_cluster.cluster_id
#   organization_id = module.castai_omni_cluster.organization_id
#
#   region         = var.oci_region
#   tenancy_id     = var.oci_tenancy_id
#   compartment_id = var.oci_compartment_id
#
#   tags = {
#     ManagedBy = "terraform"
#   }
# }
