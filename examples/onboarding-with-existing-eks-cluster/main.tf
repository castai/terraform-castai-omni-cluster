data "aws_eks_cluster" "eks" {
  name   = var.eks_cluster_name
  region = var.eks_cluster_region
}

data "aws_vpc" "eks_vpc" {
  id     = data.aws_eks_cluster.eks.vpc_config[0].vpc_id
  region = var.eks_cluster_region
}

module "castai_omni_cluster" {
  source = "../.."

  k8s_provider    = "eks"
  api_url         = var.castai_api_url
  api_token       = var.castai_api_token
  organization_id = var.organization_id
  cluster_id      = var.cluster_id
  cluster_name    = var.eks_cluster_name

  api_server_address = data.aws_eks_cluster.eks.endpoint
  pod_cidr           = data.aws_vpc.eks_vpc.cidr_block
  service_cidr       = data.aws_eks_cluster.eks.kubernetes_network_config[0].service_ipv4_cidr

  skip_helm = var.skip_helm
}

module "castai_omni_edge_location_aws" {
  source  = "castai/omni-edge-location-aws/castai"
  version = "~> 1"

  providers = {
    aws = aws.eu_west_1
  }

  cluster_id      = module.castai_omni_cluster.cluster_id
  organization_id = module.castai_omni_cluster.organization_id
  region          = "eu-west-1"
  zones           = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]

  tags = {
    ManagedBy = "terraform"
  }
}
