# =============================================================================
# Prometheus monitoring stack + blackbox exporter for edge latency metrics
#
# kube-prometheus-stack installs Prometheus (with Operator), Alertmanager,
# Grafana, and node-exporter. Prometheus is pinned to regular AKS nodes via
# nodeAffinity (liqo.io/type DoesNotExist) so it never lands on the Linode
# edge node.
#
# prometheus-blackbox-exporter probes the edge-http-server service and exposes
# probe_duration_seconds / probe_success metrics on :9115/metrics. Its
# ServiceMonitor (labelled release=kube-prometheus-stack) is auto-discovered by
# the Prometheus instance above.
# =============================================================================

resource "helm_release" "kube_prometheus_stack" {
  name             = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  namespace        = "monitoring"
  create_namespace = true
  wait             = true

  values = [
    yamlencode({
      prometheus = {
        prometheusSpec = {
          retention = "7d"
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
        }
      }

      # Grafana dashboard provisioning. kube-prometheus-stack automatically
      # configures the Prometheus datasource in Grafana (uid="prometheus") —
      # we only need to provide a dashboardProviders entry and the dashboard
      # JSON. The chart creates a ConfigMap and loads it into Grafana's
      # provisioning directory.
      grafana = {
        dashboardProviders = {
          dashboardproviders_yaml = {
            apiVersion = 1
            providers = [
              {
                name            = "default"
                orgId           = 1
                folder          = ""
                type            = "file"
                disableDeletion = false
                editable        = true
                options = {
                  path = "/var/lib/grafana/dashboards/default"
                }
              }
            ]
          }
        }

        dashboards = {
          default = {
            "edge-http-latency" = {
              json = jsonencode({
                title  = "Edge HTTP Latency"
                schema = 1
                datasource = {
                  type = "prometheus"
                  uid  = "prometheus"
                }
                panels = [
                  {
                    title = "Edge HTTP Latency (seconds)"
                    type  = "timeseries"
                    datasource = {
                      type = "prometheus"
                      uid  = "prometheus"
                    }
                    gridPos = {
                      h = 8
                      w = 24
                      x = 0
                      y = 0
                    }
                    targets = [
                      {
                        expr   = "probe_duration_seconds"
                        legend = "{{instance}}"
                        refId  = "A"
                      }
                    ]
                    fieldConfig = {
                      defaults = {
                        unit = "s"
                      }
                    }
                  }
                ]
              })
            }
          }
        }
      }
    })
  ]
}
