locals {
  omninet_cidr = "100.127.0.0/16"
  vpc_cidr     = "10.40.0.0/16"
  service_cidr = "10.96.0.0/16"
}

resource "aws_vpc" "omni" {
  cidr_block           = local.vpc_cidr
  enable_dns_hostnames = true

  tags = { Name = "${var.cluster_name}-vpc" }
}

resource "aws_internet_gateway" "omni" {
  vpc_id = aws_vpc.omni.id
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "public" {
  count = 3

  vpc_id                  = aws_vpc.omni.id
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  cidr_block              = "10.40.${count.index}.0/24"
  map_public_ip_on_launch = true

  tags = { Name = "${var.cluster_name}-public-${count.index}" }
}

resource "aws_route_table" "omni" {
  vpc_id = aws_vpc.omni.id

  tags = { Name = "${var.cluster_name}-rt" }
}

resource "aws_route" "internet" {
  route_table_id         = aws_route_table.omni.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.omni.id
}

resource "aws_route_table_association" "public" {
  count = 3

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.omni.id
}

resource "aws_iam_role" "cluster" {
  name = "${var.cluster_name}-eks-cluster"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "cluster" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role" "node" {
  name = "${var.cluster_name}-eks-node"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "node" {
  count = 3

  role = aws_iam_role.node.name
  policy_arn = [
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
  ][count.index]
}

resource "aws_eks_cluster" "omni" {
  name     = var.cluster_name
  role_arn = aws_iam_role.cluster.arn

  version = "1.36"

  vpc_config {
    subnet_ids             = aws_subnet.public[*].id
    endpoint_public_access = true
  }

  access_config {
    authentication_mode = "API_AND_CONFIG_MAP"
  }

  kubernetes_network_config {
    service_ipv4_cidr = local.service_cidr
  }

  depends_on = [aws_iam_role_policy_attachment.cluster, aws_internet_gateway.omni, aws_route.internet]
}

locals {
  caller_arn = data.aws_caller_identity.current.arn
  creator_principal = can(regex("assumed-role", local.caller_arn)) ? "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-reserved/sso.amazonaws.com/${regex("assumed-role/([^/]+)", local.caller_arn)[0]}" : local.caller_arn
}

resource "aws_eks_access_entry" "creator" {
  cluster_name  = aws_eks_cluster.omni.name
  principal_arn = local.creator_principal
}

resource "time_sleep" "creator_entry_propagation" {
  depends_on      = [aws_eks_access_entry.creator]
  create_duration = "30s"
}

resource "aws_eks_access_policy_association" "creator" {
  cluster_name  = aws_eks_cluster.omni.name
  principal_arn = local.creator_principal
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [time_sleep.creator_entry_propagation]
}

resource "aws_iam_openid_connect_provider" "cluster" {
  url = aws_eks_cluster.omni.identity[0].oidc[0].issuer

  # The provider's certificate chain is publicly trusted; AWS ignores the
  # thumbprint for such providers.
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["0000000000000000000000000000000000000000"]
}

resource "aws_iam_role" "edge" {
  name = "${var.cluster_name}-edge"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.cluster.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${replace(aws_eks_cluster.omni.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:castai-omni:omni-edge-bootstrap"
        }
      }
    }]
  })
}

resource "time_sleep" "edge_role_propagation" {
  depends_on      = [aws_iam_role.edge]
  create_duration = "30s"
}

resource "aws_eks_access_entry" "edge" {
  cluster_name  = aws_eks_cluster.omni.name
  principal_arn = aws_iam_role.edge.arn
  type          = "EC2"

  depends_on = [time_sleep.edge_role_propagation]
}

resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.omni.name
  addon_name   = "vpc-cni"
  depends_on   = [aws_eks_cluster.omni]
}

resource "aws_eks_node_group" "omni" {
  cluster_name    = aws_eks_cluster.omni.name
  node_group_name = "e2e-nodes"
  node_role_arn   = aws_iam_role.node.arn


  subnet_ids     = aws_subnet.public[*].id
  instance_types = [var.node_instance_type]
  disk_size      = 100
  scaling_config {
    desired_size = var.cluster_nodes
    min_size     = var.cluster_nodes
    max_size     = var.cluster_nodes
  }

  depends_on = [aws_eks_addon.vpc_cni]
}

resource "aws_eks_addon" "coredns" {
  cluster_name = aws_eks_cluster.omni.name
  addon_name   = "coredns"
  depends_on   = [aws_eks_node_group.omni]
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name = aws_eks_cluster.omni.name
  addon_name   = "kube-proxy"
  depends_on   = [aws_eks_node_group.omni]
}

resource "aws_iam_role" "greetings" {
  name = "${var.cluster_name}-greetings"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.cluster.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${replace(aws_eks_cluster.omni.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:omni-demo:greeting-writer"
        }
      }
    }]
  })
}

resource "aws_s3_bucket" "greetings" {
  bucket        = "${var.cluster_name}-greetings"
  force_destroy = true
}

resource "aws_iam_role_policy" "greetings" {
  name = "read-write"
  role = aws_iam_role.greetings.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"]
      Resource = [aws_s3_bucket.greetings.arn, "${aws_s3_bucket.greetings.arn}/*"]
    }]
  })
}

resource "aws_iam_role" "lbc" {
  name = "${var.cluster_name}-lbc"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.cluster.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${replace(aws_eks_cluster.omni.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "lbc" {
  name = "aws-load-balancer-controller"
  role = aws_iam_role.lbc.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Action    = ["iam:CreateServiceLinkedRole"]
        Resource  = "*"
        Condition = { StringEquals = { "iam:AWSServiceName" = "elasticloadbalancing.amazonaws.com" } }
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeAccountAttributes", "ec2:DescribeAddresses", "ec2:DescribeAvailabilityZones",
          "ec2:DescribeInternetGateways", "ec2:DescribeVpcs", "ec2:DescribeVpcPeeringConnections",
          "ec2:DescribeSubnets", "ec2:DescribeSecurityGroups", "ec2:DescribeInstances",
          "ec2:DescribeNetworkInterfaces", "ec2:DescribeTags", "ec2:GetCoipPoolUsage",
          "ec2:DescribeCoipPools", "ec2:GetSecurityGroupsForVpc", "ec2:DescribeIpamPools",
          "ec2:DescribeRouteTables",
          "elasticloadbalancing:DescribeLoadBalancers", "elasticloadbalancing:DescribeLoadBalancerAttributes",
          "elasticloadbalancing:DescribeListeners", "elasticloadbalancing:DescribeListenerCertificates",
          "elasticloadbalancing:DescribeSSLPolicies", "elasticloadbalancing:DescribeRules",
          "elasticloadbalancing:DescribeTargetGroups", "elasticloadbalancing:DescribeTargetGroupAttributes",
          "elasticloadbalancing:DescribeTargetHealth", "elasticloadbalancing:DescribeTags",
          "elasticloadbalancing:DescribeTrustStores", "elasticloadbalancing:DescribeListenerAttributes",
          "elasticloadbalancing:DescribeCapacityReservation"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["ec2:AuthorizeSecurityGroupIngress", "ec2:RevokeSecurityGroupIngress"]
        Resource = "*"
      },
      { Effect = "Allow", Action = ["ec2:CreateSecurityGroup"], Resource = "*" },
      {
        Effect   = "Allow"
        Action   = ["ec2:CreateTags"]
        Resource = "arn:aws:ec2:*:*:security-group/*"
        Condition = {
          StringEquals = { "ec2:CreateAction" = "CreateSecurityGroup" }
          Null         = { "aws:RequestTag/elbv2.k8s.aws/cluster" = "false" }
        }
      },
      {
        Effect    = "Allow"
        Action    = ["ec2:CreateTags", "ec2:DeleteTags"]
        Resource  = "arn:aws:ec2:*:*:security-group/*"
        Condition = { Null = { "aws:RequestTag/elbv2.k8s.aws/cluster" = "true", "aws:ResourceTag/elbv2.k8s.aws/cluster" = "false" } }
      },
      {
        Effect    = "Allow"
        Action    = ["ec2:AuthorizeSecurityGroupIngress", "ec2:RevokeSecurityGroupIngress", "ec2:DeleteSecurityGroup"]
        Resource  = "*"
        Condition = { Null = { "aws:ResourceTag/elbv2.k8s.aws/cluster" = "false" } }
      },
      {
        Effect    = "Allow"
        Action    = ["elasticloadbalancing:CreateLoadBalancer", "elasticloadbalancing:CreateTargetGroup"]
        Resource  = "*"
        Condition = { Null = { "aws:RequestTag/elbv2.k8s.aws/cluster" = "false" } }
      },
      {
        Effect   = "Allow"
        Action   = ["elasticloadbalancing:CreateListener", "elasticloadbalancing:DeleteListener", "elasticloadbalancing:CreateRule", "elasticloadbalancing:DeleteRule"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = ["elasticloadbalancing:AddTags", "elasticloadbalancing:RemoveTags"]
        Resource = [
          "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
          "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
          "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
        ]
        Condition = { Null = { "aws:RequestTag/elbv2.k8s.aws/cluster" = "true", "aws:ResourceTag/elbv2.k8s.aws/cluster" = "false" } }
      },
      {
        Effect = "Allow"
        Action = ["elasticloadbalancing:AddTags", "elasticloadbalancing:RemoveTags"]
        Resource = [
          "arn:aws:elasticloadbalancing:*:*:listener/net/*/*/*",
          "arn:aws:elasticloadbalancing:*:*:listener/app/*/*/*",
          "arn:aws:elasticloadbalancing:*:*:listener-rule/net/*/*/*",
          "arn:aws:elasticloadbalancing:*:*:listener-rule/app/*/*/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:ModifyLoadBalancerAttributes", "elasticloadbalancing:SetIpAddressType",
          "elasticloadbalancing:SetSecurityGroups", "elasticloadbalancing:SetSubnets",
          "elasticloadbalancing:DeleteLoadBalancer", "elasticloadbalancing:ModifyTargetGroup",
          "elasticloadbalancing:ModifyTargetGroupAttributes", "elasticloadbalancing:DeleteTargetGroup",
          "elasticloadbalancing:ModifyListenerAttributes", "elasticloadbalancing:ModifyCapacityReservation"
        ]
        Resource  = "*"
        Condition = { Null = { "aws:ResourceTag/elbv2.k8s.aws/cluster" = "false" } }
      },
      {
        Effect = "Allow"
        Action = ["elasticloadbalancing:AddTags"]
        Resource = [
          "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
          "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
          "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
        ]
        Condition = {
          StringEquals = { "elasticloadbalancing:CreateAction" = ["CreateTargetGroup", "CreateLoadBalancer"] }
          Null         = { "aws:RequestTag/elbv2.k8s.aws/cluster" = "false" }
        }
      },
      {
        Effect   = "Allow"
        Action   = ["elasticloadbalancing:RegisterTargets", "elasticloadbalancing:DeregisterTargets"]
        Resource = "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*"
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:SetWebAcl", "elasticloadbalancing:ModifyListener",
          "elasticloadbalancing:AddListenerCertificates", "elasticloadbalancing:RemoveListenerCertificates",
          "elasticloadbalancing:ModifyRule", "elasticloadbalancing:SetRulePriorities"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "helm_release" "lbc" {
  name       = "aws-load-balancer-controller"
  namespace  = "kube-system"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "1.13.2"

  set {
    name  = "clusterName"
    value = aws_eks_cluster.omni.name
  }
  set {
    name  = "region"
    value = var.region
  }
  set {
    name  = "vpcId"
    value = aws_vpc.omni.id
  }
  set {
    name  = "serviceAccount.create"
    value = "true"
  }
  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.lbc.arn
  }

  depends_on = [aws_iam_role_policy.lbc, aws_eks_addon.coredns, aws_eks_access_policy_association.creator]
}
