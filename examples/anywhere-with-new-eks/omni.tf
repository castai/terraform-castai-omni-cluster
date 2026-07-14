data "aws_vpc" "this" {
  id = module.eks_vpc.vpc_id
}

locals {
  pod_cidrs = [
    for assoc in data.aws_vpc.this.cidr_block_associations : assoc.cidr_block
    if assoc.state == "associated"
  ]
}

resource "aws_vpc_security_group_ingress_rule" "node_from_edge_location" {
  security_group_id = module.eks.node_security_group_id
  cidr_ipv4         = "10.2.0.0/16"
  ip_protocol       = "-1"
  description       = "Allow all traffic from edge location VPC"
}

resource "aws_vpc_security_group_egress_rule" "node_to_edge_location" {
  security_group_id = module.eks.node_security_group_id
  cidr_ipv4         = "10.2.0.0/16"
  ip_protocol       = "-1"
  description       = "Allow all traffic from EKS nodes to edge location VPC"
}

module "castai_omni_cluster" {
  source = "../.."

  k8s_provider    = "eks"
  api_url         = var.castai_api_url
  kvisor_grpc_url = var.kvisor_grpc_url
  api_token       = var.castai_api_token
  organization_id = var.organization_id
  cluster_id      = local.cluster_id
  cluster_name    = var.cluster_name
  cluster_region  = var.cluster_region

  pod_cidrs          = local.pod_cidrs
  api_server_address = module.eks.cluster_endpoint
  service_cidr       = module.eks.cluster_service_cidr

  storage_provider      = var.storage_provider
  loadbalancer_provider = var.loadbalancer_provider

  depends_on = [helm_release.castai_cluster_controller]
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
  zones           = ["eu-south-2a", "eu-south-2b"]
  name            = var.edge_location_name

  tags = {
    ManagedBy = "terraform"
  }

  depends_on = [module.castai_omni_cluster]
}
