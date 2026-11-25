data "aws_eks_cluster" "eks" {
  name   = var.eks_cluster_name
  region = var.eks_cluster_region
}

data "aws_vpc" "eks_vpc" {
  id     = data.aws_eks_cluster.eks.vpc_config[0].vpc_id
  region = var.eks_cluster_region
}

locals {
  pod_cidrs = [
    for assoc in data.aws_vpc.eks_vpc.cidr_block_associations : assoc.cidr_block
    if assoc.state == "associated"
  ]
}

module "castai_omni_cluster" {
  source = "../.."

  k8s_provider    = "eks"
  api_url         = var.castai_api_url
  kvisor_grpc_url = var.kvisor_grpc_url
  api_token       = var.castai_api_token
  organization_id = var.organization_id
  cluster_id      = var.cluster_id
  cluster_name    = var.eks_cluster_name
  namespace       = var.namespace

  api_server_address = data.aws_eks_cluster.eks.endpoint
  pod_cidrs          = local.pod_cidrs
  service_cidr       = data.aws_eks_cluster.eks.kubernetes_network_config[0].service_ipv4_cidr

  storage_provider      = var.storage_provider
  loadbalancer_provider = var.loadbalancer_provider
  skip_helm             = var.skip_helm

  install_omni_connect = true
  omni_connect         = var.omni_connect
}
