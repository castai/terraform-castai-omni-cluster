resource "aws_security_group" "eks_ecr_endpoints" {
  name_prefix = "${var.cluster_name}-eks-ecr-endpoints"
  vpc_id      = module.eks_vpc.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [module.eks_vpc.vpc_cidr_block]
  }
}

resource "aws_vpc_endpoint" "eks_ecr_api" {
  vpc_id              = module.eks_vpc.vpc_id
  service_name        = "com.amazonaws.${var.cluster_region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.eks_vpc.private_subnets
  security_group_ids  = [aws_security_group.eks_ecr_endpoints.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "eks_ecr_dkr" {
  vpc_id              = module.eks_vpc.vpc_id
  service_name        = "com.amazonaws.${var.cluster_region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.eks_vpc.private_subnets
  security_group_ids  = [aws_security_group.eks_ecr_endpoints.id]
  private_dns_enabled = true
}

# S3 gateway endpoint for ECR image layer pulls
resource "aws_vpc_endpoint" "eks_s3" {
  vpc_id            = module.eks_vpc.vpc_id
  service_name      = "com.amazonaws.${var.cluster_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = concat(module.eks_vpc.private_route_table_ids, module.eks_vpc.public_route_table_ids)
}

resource "aws_ecr_repository" "ecr_in_peered_vpc" {
  name                 = "${var.cluster_name}-ecr-in-peered-vpc"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = false
  }
}

resource "aws_security_group" "ecr_endpoints" {
  name_prefix = "${var.cluster_name}-ecr-endpoints"
  vpc_id      = module.peered_vpc.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [module.peered_vpc.vpc_cidr_block, module.eks_vpc.vpc_cidr_block]
  }
}

resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = module.peered_vpc.vpc_id
  service_name        = "com.amazonaws.${var.cluster_region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.peered_vpc.private_subnets
  security_group_ids  = [aws_security_group.ecr_endpoints.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = module.peered_vpc.vpc_id
  service_name        = "com.amazonaws.${var.cluster_region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.peered_vpc.private_subnets
  security_group_ids  = [aws_security_group.ecr_endpoints.id]
  private_dns_enabled = true
}

# S3 gateway endpoint is required for ECR to pull image layers
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.peered_vpc.vpc_id
  service_name      = "com.amazonaws.${var.cluster_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = concat(module.peered_vpc.private_route_table_ids, module.peered_vpc.public_route_table_ids)
}