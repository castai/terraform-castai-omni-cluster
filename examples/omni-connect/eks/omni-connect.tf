locals {
  ns = "castai-omni"
}

resource "local_file" "kubeconfig" {
  content = yamlencode({
    apiVersion = "v1"
    kind       = "Config"
    clusters = [{
      name = var.cluster_name
      cluster = {
        server                     = aws_eks_cluster.omni.endpoint
        certificate-authority-data = aws_eks_cluster.omni.certificate_authority[0].data
      }
    }]
    users = [{
      name = var.cluster_name
      user = {
        exec = {
          apiVersion = "client.authentication.k8s.io/v1beta1"
          command    = "aws"
          args       = ["eks", "get-token", "--cluster-name", var.cluster_name, "--region", var.region, "--output", "json"]
        }
      }
    }]
    contexts = [{
      name    = var.cluster_name
      context = { cluster = var.cluster_name, user = var.cluster_name }
    }]
    current-context = var.cluster_name
  })
  filename        = "${path.module}/.kubeconfig"
  file_permission = "0600"
}

resource "helm_release" "omni" {
  name             = "omni-connect"
  namespace        = local.ns
  create_namespace = true
  wait             = true
  wait_for_jobs    = true
  timeout = 900

  repository = "oci://${var.registry}"
  chart      = "omni-connect"
  version    = var.chart_version

  values = [yamlencode({
    clusterAgent = {
      image = { repository = "${var.registry}/omni-cluster-agent", tag = var.chart_version }
    }
    controlPlane = {
      service = {
        type = "LoadBalancer"
        annotations = {
          "service.beta.kubernetes.io/aws-load-balancer-scheme" = "internet-facing"
        }
      }
      workloadIdentity = {
        # Enables the edge metadata proxy: pods on the edge assume the
        # role annotated on their service account at STS.
        aws = true
      }
      postgres = {
        persistence = {
          # EKS ships no default storage class, so the PVC must name one
          # explicitly: the gp2 class pre-created on this cluster serves
          # the control plane database.
          storageClass = "local-path"
        }
      }
    }
    omninet = {
      # In-cluster control plane URL: the edge resolves it through the
      # omninet overlay, no public endpoint needed.
      controlURL = "http://omni-controlplane.${local.ns}.svc.cluster.local:443"
      nodeAgent = {
        image = { repository = "${var.registry}/omni-node-agent", tag = var.chart_version }
      }
      gatewayLB             = { enabled = true }
      cidr                  = local.omninet_cidr
      kubeletProxyTokenAuth = true
      # Virtual nodes: every edge gets a forwarding pod, and the edge
      # kubelet joins with that pod's IP as its node IP - the EKS API
      # server dials an ordinary pod address, so nothing of the omninet
      # overlay is routed in the VPC.
      virtualNodes = true
      # The edge's identity on EKS: the kubelet proxy assumes the edge role
      # with the node name as its STS session, and the EC2 access entry
      # maps it to system:node:<node name>.
      kubeletAWS = {
        nodeRoleARN  = aws_iam_role.edge.arn
        clusterName  = var.cluster_name
        nodeIdentity = true
        # EKS never issues the standard kubelet-serving certificates for
        # nodes it did not launch; the edge requests one through the
        # app-serving signer and the chart's CSR approver signs it.
        servingSigner = "beta.eks.amazonaws.com/app-serving"
      }
    }
  })]

  depends_on = [helm_release.lbc, aws_eks_access_entry.edge, aws_eks_access_policy_association.creator]
}

module "edge_join" {
  source = "../modules/edge-join"

  edges            = local.edges
  kubeconfig_path  = abspath(local_file.kubeconfig.filename)
  ssh_key_path     = abspath(local_file.edge_ssh_key.filename)
  known_hosts_path = "${path.module}/.edge_known_hosts"

  dependencies = [
    helm_release.omni.id,
    local_file.kubeconfig.id,
  ]
}
