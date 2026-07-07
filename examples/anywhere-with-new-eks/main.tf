resource "kubernetes_namespace_v1" "castai_agent" {
  metadata {
    name = "castai-agent"
    labels = {
      "app.kubernetes.io/managed-by" = "Helm"
    }
    annotations = {
      "meta.helm.sh/release-name"      = "castai-agent"
      "meta.helm.sh/release-namespace" = "castai-agent"
    }
  }
}

# Install CAST AI Agent
resource "helm_release" "castai_agent" {
  name             = "castai-agent"
  repository       = "https://castai.github.io/helm-charts"
  chart            = "castai-agent"
  namespace        = kubernetes_namespace_v1.castai_agent.metadata[0].name
  create_namespace = false
  timeout          = 600

  set = concat(
    [
      {
        name  = "clusterName"
        value = var.cluster_name
      },
      {
        name  = "provider"
        value = "anywhere"
      },
      {
        name  = "additionalEnv.ANYWHERE_CLUSTER_NAME"
        value = var.cluster_name
      },
    ],
    var.castai_api_url != "" ? [{
      name  = "apiURL"
      value = var.castai_api_url
    }] : [],
  )

  set_sensitive = [
    {
      name  = "apiKey"
      value = var.castai_api_token
    },
  ]

  depends_on = [kubernetes_storage_class_v1.gp3, helm_release.aws_load_balancer_controller]
}

# Wait until the castai-agent has written its metadata ConfigMap
resource "null_resource" "wait_for_castai_agent_metadata" {
  provisioner "local-exec" {
    command = <<-EOT
      KUBECONFIG_FILE=$(mktemp)
      trap 'rm -f "$KUBECONFIG_FILE"' EXIT

      aws eks update-kubeconfig \
        --name ${var.cluster_name} \
        --region ${var.cluster_region} \
        --kubeconfig "$KUBECONFIG_FILE"

      TIMEOUT=300
      INTERVAL=10
      ELAPSED=0
      until kubectl --kubeconfig "$KUBECONFIG_FILE" \
              get configmap castai-agent-metadata \
              -n castai-agent 2>/dev/null; do
        if [ "$ELAPSED" -ge "$TIMEOUT" ]; then
          echo "Timed out after $${TIMEOUT}s waiting for castai-agent-metadata ConfigMap" >&2
          exit 1
        fi
        echo "Waiting for castai-agent-metadata ConfigMap... ($${ELAPSED}/$${TIMEOUT}s)"
        sleep "$INTERVAL"
        ELAPSED=$((ELAPSED + INTERVAL))
      done
    EOT
  }

  depends_on = [helm_release.castai_agent]
}

# Read CLUSTER_ID from the ConfigMap written by castai-agent
data "kubernetes_config_map_v1" "castai_agent_metadata" {
  metadata {
    name      = "castai-agent-metadata"
    namespace = "castai-agent"
  }

  depends_on = [null_resource.wait_for_castai_agent_metadata]
}

locals {
  cluster_id = try(data.kubernetes_config_map_v1.castai_agent_metadata.data["CLUSTER_ID"], "")
}

# Install CAST AI Cluster Controller
resource "helm_release" "castai_cluster_controller" {
  name             = "castai-cluster-controller"
  repository       = "https://castai.github.io/helm-charts"
  chart            = "castai-cluster-controller"
  namespace        = "castai-agent"
  create_namespace = false
  timeout          = 600

  set = [
    {
      name  = "castai.apiURL"
      value = var.castai_api_url
    },
    {
      name  = "castai.apiKey"
      value = var.castai_api_token
    },
    {
      name  = "castai.clusterID"
      value = local.cluster_id
    },
    {
      name  = "autoscaling.enabled"
      value = "false"
    }
  ]
}

# Install CAST AI Evictor
resource "helm_release" "castai_evictor" {
  name             = "castai-evictor"
  repository       = "https://castai.github.io/helm-charts"
  chart            = "castai-evictor"
  namespace        = "castai-agent"
  create_namespace = false
  timeout          = 600

  # other settings
  set = [
    {
      name  = "replicaCount"
      value = "0"
    }
  ]

  # evictor-specific settings
  values = [
    yamlencode({
      evictor = {
        aggressive_mode           = false
        cycle_interval            = "5m10s"
        dry_run                   = false
        enabled                   = true
        node_grace_period_minutes = 5
        scoped_mode               = false
      }
    })
  ]

  depends_on = [helm_release.castai_agent]
}
