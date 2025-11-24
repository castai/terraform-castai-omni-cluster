data "aws_eks_cluster" "eks" {
  name   = var.eks_cluster_name
  region = var.eks_cluster_region
}

data "aws_vpc" "eks_vpc" {
  id     = data.aws_eks_cluster.eks.vpc_config[0].vpc_id
  region = var.eks_cluster_region
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
  # Get all subnet CIDR blocks for reserved subnets
  subnet_cidrs = [for s in data.aws_subnet.eks_subnet : s.cidr_block]
}

module "castai_omni_cluster" {
  source = "../.."

  k8s_provider    = "eks"
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

module "castai_aws_edge_location" {
  source = "github.com/castai/terraform-castai-omni-edge-location-aws"

  providers = {
    aws = aws.eu_west_1
  }

  cluster_id      = module.castai_omni_cluster.cluster_id
  organization_id = module.castai_omni_cluster.organization_id
  region          = "eu-west-1"

  tags = {
    ManagedBy = "terraform"
  }
}
