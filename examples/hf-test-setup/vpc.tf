data "aws_availability_zones" "available" {}

module "eks_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"

  name = var.cluster_name
  cidr = "10.0.0.0/16"

  azs             = data.aws_availability_zones.available.names
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]

  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false

  tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  public_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = 1
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"           = 1
  }
}

module "hf_backbone_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"

  name = "${var.cluster_name}-hf-backbone"
  cidr = "10.1.0.0/16"

  azs             = data.aws_availability_zones.available.names
  private_subnets = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
  public_subnets  = ["10.1.4.0/24", "10.1.5.0/24", "10.1.6.0/24"]

  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false
}

# VPC peering: peered VPC -> EKS VPC
resource "aws_vpc_peering_connection" "peered_to_eks" {
  vpc_id      = module.hf_backbone_vpc.vpc_id
  peer_vpc_id = module.eks_vpc.vpc_id
  auto_accept = true
}

# Routes in EKS VPC private route tables -> peered VPC
resource "aws_route" "eks_private_to_peered" {
  count                     = length(module.eks_vpc.private_route_table_ids)
  route_table_id            = module.eks_vpc.private_route_table_ids[count.index]
  destination_cidr_block    = module.hf_backbone_vpc.vpc_cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.peered_to_eks.id
}

resource "aws_route" "eks_public_to_peered" {
  count                     = length(module.eks_vpc.public_route_table_ids)
  route_table_id            = module.eks_vpc.public_route_table_ids[count.index]
  destination_cidr_block    = module.hf_backbone_vpc.vpc_cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.peered_to_eks.id
}

# Routes in peered VPC route tables -> EKS VPC
resource "aws_route" "peered_private_to_eks" {
  count                     = length(module.hf_backbone_vpc.private_route_table_ids)
  route_table_id            = module.hf_backbone_vpc.private_route_table_ids[count.index]
  destination_cidr_block    = module.eks_vpc.vpc_cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.peered_to_eks.id
}

resource "aws_route" "peered_public_to_eks" {
  count                     = length(module.hf_backbone_vpc.public_route_table_ids)
  route_table_id            = module.hf_backbone_vpc.public_route_table_ids[count.index]
  destination_cidr_block    = module.eks_vpc.vpc_cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.peered_to_eks.id
}
