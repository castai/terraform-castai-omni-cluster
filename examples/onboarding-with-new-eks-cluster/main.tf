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

  aws_assume_role_arn        = module.castai_eks_role_iam.role_arn

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

  depends_on = [module.castai_eks_role_iam]
}

module "castai_omni_cluster" {
  source = "../.."

  k8s_provider    = "eks"
  api_url         = var.castai_api_url
  api_token       = var.castai_api_token
  organization_id = var.organization_id
  cluster_id      = castai_eks_clusterid.cluster_id.id
  cluster_name    = var.cluster_name
  cluster_region  = var.cluster_region

  pod_cidr           = module.eks_vpc.vpc_cidr_block
  api_server_address = module.eks.cluster_endpoint
  service_cidr       = module.eks.cluster_service_cidr

  skip_helm = var.skip_helm
}

module "castai_omni_edge_location_aws" {
  source  = "castai/omni-edge-location-aws/castai"
  version = "~> 1.0"

  providers = {
    aws = aws.eu_west_1
  }

  cluster_id      = module.castai_omni_cluster.cluster_id
  organization_id = module.castai_omni_cluster.organization_id
  region          = "eu-west-1"
  zones           = ["eu-west-1a", "eu-west-1b"]

  tags = {
    ManagedBy = "terraform"
  }
}
