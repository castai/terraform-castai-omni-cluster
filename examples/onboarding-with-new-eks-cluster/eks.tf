module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name                   = var.cluster_name
  kubernetes_version     = var.kubernetes_version
  endpoint_public_access = true

  addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent    = true
      before_compute = true
    }
    aws-ebs-csi-driver = {
      most_recent              = true
      service_account_role_arn = module.ebs_csi_driver_irsa.iam_role_arn
    }
  }

  vpc_id     = module.eks_vpc.vpc_id
  subnet_ids = module.eks_vpc.private_subnets

  enable_cluster_creator_admin_permissions = true

  self_managed_node_groups = {
    node_group_1 = {
      name          = "${var.cluster_name}-ng-1"
      instance_type = "m5.large"
      max_size      = 5
      min_size      = 2
      desired_size  = 2

      metadata_options = {
        http_endpoint               = "enabled"
        http_tokens                 = "required"
        http_put_response_hop_limit = 2
      }
    }
  }
}

# Example additional security group.
resource "aws_security_group" "additional" {
  name_prefix = "${var.cluster_name}-additional"
  vpc_id      = module.eks_vpc.vpc_id

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
    cidr_blocks = [
      "10.0.0.0/8",
    ]
  }
}

################################################################################
# AWS Load Balancer Controller
################################################################################

module "aws_load_balancer_controller_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name_prefix = "${var.cluster_name}-lb-"

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }

  attach_load_balancer_controller_policy = true
}

module "ebs_csi_driver_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name_prefix = "${var.cluster_name}-ebs-csi-"

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  attach_ebs_csi_policy = true
}

resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  namespace  = "kube-system"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "1.10.0"

  set = [
    {
      name  = "clusterName"
      value = module.eks.cluster_name
    },
    {
      name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = module.aws_load_balancer_controller_irsa.iam_role_arn
    }
  ]

  depends_on = [module.eks]
}

# EKS creates a gp2 StorageClass and marks it as default by default.
# Kubernetes does not allow multiple default StorageClasses, so we must
# remove the default annotation from gp2 before creating gp3.
resource "null_resource" "remove_gp2_default" {
  triggers = {
    cluster_name = module.eks.cluster_name
    region       = var.cluster_region
  }

  provisioner "local-exec" {
    command = <<-EOT
      aws eks update-kubeconfig --name ${self.triggers.cluster_name} --region ${self.triggers.region} --kubeconfig /tmp/kubeconfig-${self.triggers.cluster_name}.yaml
      kubectl --kubeconfig /tmp/kubeconfig-${self.triggers.cluster_name}.yaml annotate storageclass gp2 storageclass.kubernetes.io/is-default-class- --overwrite=true || true
    EOT
  }

  depends_on = [module.eks]
}

resource "kubernetes_storage_class_v1" "gp3" {
  metadata {
    name = "gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }
  storage_provisioner    = "ebs.csi.aws.com"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true
  parameters = {
    type      = "gp3"
    encrypted = "true"
  }

  depends_on = [null_resource.remove_gp2_default]
}
