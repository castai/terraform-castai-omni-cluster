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
# Security group — EKS VPC, accepts HTTPS from within the VPC only
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
