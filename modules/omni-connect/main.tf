locals {
  chart            = var.omni_connect.chart
  storage_provider = try(var.omni_connect.storage_provider, null) != null ? var.omni_connect.storage_provider : var.storage_provider
  virtual_nodes    = coalesce(try(var.omni_connect.virtual_nodes, null), var.k8s_provider == "eks" ? true : false)

  kubelet_aws = try(var.omni_connect.kubelet_aws, null)
  kubelet_aws_node_role = {
    for key, value in {
      nodeRoleARN    = try(local.kubelet_aws.node_role_arn, null)
      clusterName    = try(local.kubelet_aws.cluster_name, null)
      usernamePrefix = try(local.kubelet_aws.username_prefix, null)
      servingSigner  = try(local.kubelet_aws.serving_signer, null)
      rbacGroup      = try(local.kubelet_aws.rbac_group, null)
      nodeIdentity   = try(local.kubelet_aws.node_identity, null)
    } : key => value if value != null
  }

  cloud_cidrs         = try(var.omni_connect.cloud_cidrs, null) != null ? var.omni_connect.cloud_cidrs : []
  service_type        = try(var.omni_connect.service.type, null) != null ? var.omni_connect.service.type : "LoadBalancer"
  service_annotations = try(var.omni_connect.service.annotations, null) != null ? var.omni_connect.service.annotations : {}

  helm_values = {
    clusterAgent = {
      image = {
        repository = local.chart.cluster_agent_image.repository
        tag        = local.chart.cluster_agent_image.tag
      }
    }

    controlPlane = merge(
      {
        publicURL = try(var.omni_connect.public_url, null) != null ? var.omni_connect.public_url : ""
        service = {
          type        = local.service_type
          annotations = local.service_annotations
        }
      },
      try(trimspace(local.storage_provider), "") == "" ? {} : {
        postgres = {
          persistence = {
            storageClass = local.storage_provider
          }
        }
      }
    )

    omninet = merge(
      {
        cidr                  = coalesce(try(var.omni_connect.cidr, null), "100.127.0.0/16")
        virtualNodes          = local.virtual_nodes
        kubeletProxyTokenAuth = var.k8s_provider == "eks"
        nodeAgent = {
          image = {
            repository = local.chart.node_agent_image.repository
            tag        = local.chart.node_agent_image.tag
          }
        }
      },
      length(local.cloud_cidrs) == 0 ? {} : { cloudCIDRs = join(",", local.cloud_cidrs) },
      length(local.kubelet_aws_node_role) == 0 ? {} : { kubeletAWS = local.kubelet_aws_node_role }
    )
  }

  values = concat(
    [yamlencode(local.helm_values)],
    var.omni_connect.helm_values != null ? [yamlencode(var.omni_connect.helm_values)] : []
  )
}

resource "helm_release" "omni_connect" {
  count = var.skip_helm ? 0 : 1

  name             = "castai-omni-connect"
  namespace        = var.namespace
  repository       = local.chart.repository
  chart            = local.chart.name
  version          = local.chart.version
  create_namespace = false
  cleanup_on_fail  = true
  wait             = true
  timeout          = 1200

  values = local.values
}
