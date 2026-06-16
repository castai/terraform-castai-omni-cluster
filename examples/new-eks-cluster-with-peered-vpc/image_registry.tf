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

# =============================================================================
# VPC peering: registry VPC <-> EKS VPC
# =============================================================================

resource "aws_vpc_peering_connection" "registry_to_eks" {
  vpc_id      = module.registry_vpc.vpc_id
  peer_vpc_id = module.eks_vpc.vpc_id
  auto_accept = true
}

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

# EKS node security group rules for registry VPC traffic
resource "aws_vpc_security_group_ingress_rule" "node_from_registry_vpc" {
  security_group_id = module.eks.node_security_group_id
  cidr_ipv4         = module.registry_vpc.vpc_cidr_block
  ip_protocol       = "-1"
  description       = "Allow all traffic from registry VPC to EKS nodes"
}

resource "aws_vpc_security_group_egress_rule" "node_to_registry_vpc" {
  security_group_id = module.eks.node_security_group_id
  cidr_ipv4         = module.registry_vpc.vpc_cidr_block
  ip_protocol       = "-1"
  description       = "Allow all traffic from EKS nodes to registry VPC"
}

# =============================================================================
# Latest Amazon Linux 2023 AMI
# =============================================================================

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}

# =============================================================================
# IAM role for EC2
# =============================================================================

resource "aws_iam_role" "image_registry" {
  name_prefix = "${var.cluster_name}-image-registry"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "image_registry_ssm" {
  role       = aws_iam_role.image_registry.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "image_registry" {
  name_prefix = "${var.cluster_name}-image-registry"
  role        = aws_iam_role.image_registry.name
}

# =============================================================================
# Security group — registry VPC, accepts HTTPS from EKS VPC only
# =============================================================================

resource "aws_security_group" "image_registry" {
  name_prefix = "${var.cluster_name}-image-registry"
  vpc_id      = module.registry_vpc.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [module.eks_vpc.vpc_cidr_block]
  }

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [module.eks_vpc.vpc_cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# =============================================================================
# EBS volume for registry storage (persists across instance replacements)
# =============================================================================

resource "aws_ebs_volume" "image_registry" {
  availability_zone = module.registry_vpc.azs[0]
  size              = 50
  type              = "gp3"

  tags = {
    Name = "${var.cluster_name}-image-registry-data"
  }
}

resource "aws_volume_attachment" "image_registry" {
  device_name = "/dev/xvdf"
  volume_id   = aws_ebs_volume.image_registry.id
  instance_id = aws_instance.image_registry.id
}

resource "aws_instance" "image_registry" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = "t3.small"
  subnet_id              = module.registry_vpc.private_subnets[0]
  private_ip             = "10.4.1.253"
  iam_instance_profile   = aws_iam_instance_profile.image_registry.name
  vpc_security_group_ids = [aws_security_group.image_registry.id]

  user_data = base64encode(templatefile("${path.module}/image_registry_userdata.sh.tpl", {
    tls_cert = trimspace(var.image_registry_tls_cert)
    tls_key  = trimspace(var.image_registry_tls_key)
  }))

  tags = {
    Name = "${var.cluster_name}-image-registry"
  }
}
