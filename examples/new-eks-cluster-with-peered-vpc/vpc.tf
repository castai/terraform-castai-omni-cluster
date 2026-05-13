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

module "registry_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"

  name = "${var.cluster_name}-registry-vpc"
  cidr = "10.4.0.0/16"

  azs             = data.aws_availability_zones.available.names
  private_subnets = ["10.4.1.0/24", "10.4.2.0/24", "10.4.3.0/24"]
  public_subnets  = ["10.4.4.0/24", "10.4.5.0/24", "10.4.6.0/24"]

  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false
}

# =============================================================================
# SSM VPC endpoints for registry VPC (no public internet path for SSM agent)
# =============================================================================

resource "aws_security_group" "ssm_endpoints" {
  name_prefix = "${var.cluster_name}-ssm-endpoints"
  vpc_id      = module.registry_vpc.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [module.registry_vpc.vpc_cidr_block]
  }
}

resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = module.registry_vpc.vpc_id
  service_name        = "com.amazonaws.${var.cluster_region}.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.registry_vpc.private_subnets
  security_group_ids  = [aws_security_group.ssm_endpoints.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id              = module.registry_vpc.vpc_id
  service_name        = "com.amazonaws.${var.cluster_region}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.registry_vpc.private_subnets
  security_group_ids  = [aws_security_group.ssm_endpoints.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id              = module.registry_vpc.vpc_id
  service_name        = "com.amazonaws.${var.cluster_region}.ec2messages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.registry_vpc.private_subnets
  security_group_ids  = [aws_security_group.ssm_endpoints.id]
  private_dns_enabled = true
}

module "proxy_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"

  name = "${var.cluster_name}-proxy-vpc"
  cidr = "10.5.0.0/16"

  azs             = data.aws_availability_zones.available.names
  private_subnets = ["10.5.1.0/24", "10.5.2.0/24", "10.5.3.0/24"]
  public_subnets  = ["10.5.4.0/24", "10.5.5.0/24", "10.5.6.0/24"]

  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false
}

# VPC peering: registry VPC -> EKS VPC
resource "aws_vpc_peering_connection" "registry_to_eks" {
  vpc_id      = module.registry_vpc.vpc_id
  peer_vpc_id = module.eks_vpc.vpc_id
  auto_accept = true
}

# Routes in EKS VPC private route tables -> registry VPC
resource "aws_route" "eks_private_to_registry" {
  count                     = length(module.eks_vpc.private_route_table_ids)
  route_table_id            = module.eks_vpc.private_route_table_ids[count.index]
  destination_cidr_block    = module.registry_vpc.vpc_cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.registry_to_eks.id
}

resource "aws_route" "eks_public_to_registry" {
  count                     = length(module.eks_vpc.public_route_table_ids)
  route_table_id            = module.eks_vpc.public_route_table_ids[count.index]
  destination_cidr_block    = module.registry_vpc.vpc_cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.registry_to_eks.id
}

# Routes in registry VPC route tables -> EKS VPC
resource "aws_route" "registry_private_to_eks" {
  count                     = length(module.registry_vpc.private_route_table_ids)
  route_table_id            = module.registry_vpc.private_route_table_ids[count.index]
  destination_cidr_block    = module.eks_vpc.vpc_cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.registry_to_eks.id
}

resource "aws_route" "registry_public_to_eks" {
  count                     = length(module.registry_vpc.public_route_table_ids)
  route_table_id            = module.registry_vpc.public_route_table_ids[count.index]
  destination_cidr_block    = module.eks_vpc.vpc_cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.registry_to_eks.id
}

# VPC peering: proxy VPC -> EKS VPC
resource "aws_vpc_peering_connection" "proxy_to_eks" {
  vpc_id      = module.proxy_vpc.vpc_id
  peer_vpc_id = module.eks_vpc.vpc_id
  auto_accept = true
}

resource "aws_route" "eks_private_to_proxy" {
  count                     = length(module.eks_vpc.private_route_table_ids)
  route_table_id            = module.eks_vpc.private_route_table_ids[count.index]
  destination_cidr_block    = module.proxy_vpc.vpc_cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.proxy_to_eks.id
}

resource "aws_route" "eks_public_to_proxy" {
  count                     = length(module.eks_vpc.public_route_table_ids)
  route_table_id            = module.eks_vpc.public_route_table_ids[count.index]
  destination_cidr_block    = module.proxy_vpc.vpc_cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.proxy_to_eks.id
}

resource "aws_route" "proxy_private_to_eks" {
  count                     = length(module.proxy_vpc.private_route_table_ids)
  route_table_id            = module.proxy_vpc.private_route_table_ids[count.index]
  destination_cidr_block    = module.eks_vpc.vpc_cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.proxy_to_eks.id
}

resource "aws_route" "proxy_public_to_eks" {
  count                     = length(module.proxy_vpc.public_route_table_ids)
  route_table_id            = module.proxy_vpc.public_route_table_ids[count.index]
  destination_cidr_block    = module.eks_vpc.vpc_cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.proxy_to_eks.id
}

# VPC peering: proxy VPC -> registry VPC
resource "aws_vpc_peering_connection" "proxy_to_registry" {
  vpc_id      = module.proxy_vpc.vpc_id
  peer_vpc_id = module.registry_vpc.vpc_id
  auto_accept = true
}

resource "aws_route" "registry_private_to_proxy" {
  count                     = length(module.registry_vpc.private_route_table_ids)
  route_table_id            = module.registry_vpc.private_route_table_ids[count.index]
  destination_cidr_block    = module.proxy_vpc.vpc_cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.proxy_to_registry.id
}

resource "aws_route" "registry_public_to_proxy" {
  count                     = length(module.registry_vpc.public_route_table_ids)
  route_table_id            = module.registry_vpc.public_route_table_ids[count.index]
  destination_cidr_block    = module.proxy_vpc.vpc_cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.proxy_to_registry.id
}

resource "aws_route" "proxy_private_to_registry" {
  count                     = length(module.proxy_vpc.private_route_table_ids)
  route_table_id            = module.proxy_vpc.private_route_table_ids[count.index]
  destination_cidr_block    = module.registry_vpc.vpc_cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.proxy_to_registry.id
}

resource "aws_route" "proxy_public_to_registry" {
  count                     = length(module.proxy_vpc.public_route_table_ids)
  route_table_id            = module.proxy_vpc.public_route_table_ids[count.index]
  destination_cidr_block    = module.registry_vpc.vpc_cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.proxy_to_registry.id
}
