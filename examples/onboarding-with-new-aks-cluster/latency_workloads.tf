# =============================================================================
# Latency measurement workloads
#
# HTTP server (nginx) deployed on the Linode edge node via the
# omni.cast.ai/edge-node nodeSelector, serving a minimal static page.
#
# The blackbox exporter runs on regular AKS nodes and probes the
# edge-http-server service, exposing probe_duration_seconds /
# probe_success metrics on :9115/metrics for Prometheus to scrape.
#
# Dependency chain:
#   null_resource.wait_for_edge_node_ready (linode.tf)
#     → kubernetes_deployment.http_server
#       → kubernetes_service.http_server
#         → helm_release.blackbox_exporter
# =============================================================================

resource "kubernetes_namespace" "latency" {
  metadata {
    name = "latency"
    labels = {
      # Enable Cast AI Omni scheduling to the Linode edge node (Liqo remote offloading).
      # The omni-agent's default SchedulingPolicy matches this label and creates
      # the Liqo NamespaceOffloading with podOffloadingStrategy: LocalAndRemote.
      "omni.cast.ai/enable-scheduling" = "true"
    }
  }
}

resource "kubernetes_config_map" "edge_index" {
  metadata {
    name      = "edge-index-html"
    namespace = kubernetes_namespace.latency.metadata[0].name
  }

  data = {
    "index.html" = "ok"
  }
}

resource "kubernetes_deployment" "http_server" {
  metadata {
    name      = "edge-http-server"
    namespace = kubernetes_namespace.latency.metadata[0].name
    labels = {
      app = "edge-http-server"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "edge-http-server"
      }
    }

    template {
      metadata {
        labels = {
          app = "edge-http-server"
        }
      }

      spec {
        # Schedule on the Linode edge node only.
        node_selector = {
          "omni.cast.ai/edge-node" = "true"
        }

        # Tolerate the edge node's not-allowed taint.
        toleration {
          key      = "virtual-node.omni.cast.ai/not-allowed"
          operator = "Equal"
          value    = "true"
          effect   = "NoExecute"
        }

        container {
          name  = "nginx"
          image = "nginx:alpine"

          port {
            container_port = 80
          }

          # Minimal static page for deterministic latency measurement.
          volume_mount {
            name       = "index-html"
            mount_path = "/usr/share/nginx/html/index.html"
            sub_path   = "index.html"
          }
        }

        volume {
          name = "index-html"
          config_map {
            name = kubernetes_config_map.edge_index.metadata[0].name
          }
        }
      }
    }
  }

  depends_on = [module.castai_omni_cluster, null_resource.wait_for_edge_node_ready]
}

resource "kubernetes_service" "http_server" {
  metadata {
    name      = "edge-http-server"
    namespace = kubernetes_namespace.latency.metadata[0].name
  }

  spec {
    selector = {
      app = "edge-http-server"
    }

    port {
      port        = 80
      target_port = 80
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }

  depends_on = [kubernetes_deployment.http_server]
}

# -----------------------------------------------------------------------------
# Blackbox exporter (latency client)
#
# Runs on regular AKS nodes and probes the edge-http-server service,
# exposing probe_duration_seconds / probe_success metrics on :9115/metrics.
# Its ServiceMonitor (labelled release=kube-prometheus-stack) is auto-discovered
# by the Prometheus instance provisioned in monitoring.tf.
# -----------------------------------------------------------------------------

resource "helm_release" "blackbox_exporter" {
  name       = "blackbox-exporter"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus-blackbox-exporter"
  namespace  = kubernetes_namespace.latency.metadata[0].name

  values = [
    yamlencode({
      config = {
        modules = {
          http_2xx = {
            prober  = "http"
            timeout = "5s"
            http = {
              preferred_ip_protocol = "ip4"
            }
          }
        }
      }

      affinity = {
        nodeAffinity = {
          requiredDuringSchedulingIgnoredDuringExecution = {
            nodeSelectorTerms = [
              {
                matchExpressions = [
                  {
                    key      = "liqo.io/type"
                    operator = "DoesNotExist"
                  }
                ]
              }
            ]
          }
        }
      }

      serviceMonitor = {
        enabled = true
        defaults = {
          interval      = "5s"
          scrapeTimeout = "5s"
          module        = "http_2xx"
          labels = {
            release = "kube-prometheus-stack"
          }
        }
        targets = [
          {
            name = "edge-http-server"
            url  = "http://edge-http-server.${kubernetes_namespace.latency.metadata[0].name}.svc.cluster.local/"
          }
        ]
      }
    })
  ]

  depends_on = [helm_release.kube_prometheus_stack, kubernetes_service.http_server]
}
