mock_provider "castai" {}
mock_provider "helm" {}
mock_provider "kubernetes" {}
mock_provider "external" {}
mock_provider "null" {}

variables {
  k8s_provider          = "eks"
  api_token             = "test-only-token"
  organization_id       = "org-test"
  cluster_id            = "cluster-test"
  cluster_name          = "test-cluster"
  api_server_address    = "https://cluster.example.com"
  pod_cidrs             = ["10.244.0.0/16"]
  service_cidr          = "10.96.0.0/16"
  reserved_subnet_cidrs = ["10.0.0.0/16"]

  omni_connect = {
    chart = {
      repository = "oci://registry.example.com/charts"
      version    = "0.1.0-test"
      cluster_agent_image = {
        repository = "registry.example.com/castai/omni-cluster-agent"
        tag        = "0.1.0-test"
      }
      node_agent_image = {
        repository = "registry.example.com/castai/omni-node-agent"
        tag        = "0.1.0-test"
      }
    }
    public_url = "https://omni.example.com"
  }
}

run "disabled_by_default" {
  command = plan

  assert {
    condition     = length(module.omni_connect) == 0
    error_message = "Omni-Connect must not be installed when opt-in is absent"
  }

  assert {
    condition     = output.omni_connect_release == null
    error_message = "Disabled configuration must not return a Helm release"
  }
}

run "disabled_gitops" {
  command = plan

  variables {
    skip_helm = true
  }

  assert {
    condition     = !contains(keys(kubernetes_config_map_v1.helm_values[0].data), "omni-connect.chart")
    error_message = "The GitOps ConfigMap must remain unchanged when Omni-Connect is disabled"
  }
}

run "enabled_eks" {
  command = plan

  variables {
    install_omni_connect = true
  }

  assert {
    condition     = length(module.omni_connect) == 1
    error_message = "Opt-in should instantiate the Omni-Connect module"
  }

  assert {
    condition     = module.omni_connect[0].helm_values.clusterAgent.image.tag == "0.1.0-test"
    error_message = "The explicitly selected cluster-agent image tag must be propagated"
  }

  assert {
    condition     = module.omni_connect[0].helm_values.controlPlane.publicURL == "https://omni.example.com"
    error_message = "The configured public control-plane URL must be propagated"
  }

  assert {
    condition     = module.omni_connect[0].helm_values.controlPlane.postgres.persistence.storageClass == "gp3"
    error_message = "EKS must default the control-plane database to gp3"
  }

  assert {
    condition     = module.omni_connect[0].helm_values.omninet.virtualNodes && module.omni_connect[0].helm_values.omninet.kubeletProxyTokenAuth
    error_message = "EKS must use virtual nodes and kubelet proxy token authentication"
  }

  assert {
    condition     = output.omni_connect_release.name == "castai-omni-connect"
    error_message = "Deployment without skip_helm must create the Omni-Connect release"
  }
}

run "enabled_gke" {
  command = plan

  variables {
    k8s_provider         = "gke"
    install_omni_connect = true
  }

  assert {
    condition     = module.omni_connect[0].helm_values.controlPlane.postgres.persistence.storageClass == "premium-rwo"
    error_message = "GKE must default the control-plane database to premium-rwo"
  }

  assert {
    condition     = !module.omni_connect[0].helm_values.omninet.virtualNodes && !module.omni_connect[0].helm_values.omninet.kubeletProxyTokenAuth
    error_message = "GKE must not inherit the EKS-specific virtual-node or token-auth settings"
  }
}

run "enabled_aks" {
  command = plan

  variables {
    k8s_provider         = "aks"
    install_omni_connect = true
  }

  assert {
    condition     = !contains(keys(module.omni_connect[0].helm_values.controlPlane), "postgres")
    error_message = "AKS must leave the control-plane database storage class unset"
  }

  assert {
    condition     = !module.omni_connect[0].helm_values.omninet.virtualNodes && !module.omni_connect[0].helm_values.omninet.kubeletProxyTokenAuth
    error_message = "AKS must not inherit the EKS-specific virtual-node or token-auth settings"
  }
}

run "enabled_gitops" {
  command = plan

  variables {
    install_omni_connect = true
    skip_helm            = true
  }

  assert {
    condition     = output.omni_connect_release == null
    error_message = "GitOps mode must not create a direct Helm release"
  }

  assert {
    condition     = kubernetes_config_map_v1.helm_values[0].data["omni-connect.chart"] == "omni-connect"
    error_message = "GitOps mode must export the chart name"
  }

  assert {
    condition     = kubernetes_config_map_v1.helm_values[0].data["omni-connect.version"] == "0.1.0-test"
    error_message = "GitOps mode must export the explicitly selected chart version"
  }

  assert {
    condition     = yamldecode(kubernetes_config_map_v1.helm_values[0].data["omni-connect-values.yaml"]).omninet.virtualNodes
    error_message = "GitOps and direct installation must share the provider-specific computed values"
  }

  assert {
    condition     = !contains(keys(yamldecode(kubernetes_config_map_v1.helm_values[0].data["omni-connect-values.yaml"]).omninet), "kubeletAWS")
    error_message = "GitOps and direct installation must share the provider-specific computed values"
  }
}

run "enabled_eks_kubelet_aws" {
  command = plan

  variables {
    install_omni_connect = true
    omni_connect = {
      chart = {
        repository = "oci://registry.example.com/charts"
        version    = "0.1.0-test"
        cluster_agent_image = {
          repository = "registry.example.com/castai/omni-cluster-agent"
          tag        = "0.1.0-test"
        }
        node_agent_image = {
          repository = "registry.example.com/castai/omni-node-agent"
          tag        = "0.1.0-test"
        }
      }
      kubelet_aws = {
        node_role_arn   = "arn:iam:role/omni-edge-test"
        cluster_name    = "test-cluster"
        serving_signer  = "beta.eks.amazonaws.com/app-serving"
        node_identity   = true
        username_prefix = "system:node:"
        rbac_group      = "system:nodes"
      }
    }
  }

  assert {
    condition     = module.omni_connect[0].helm_values.omninet.kubeletAWS.nodeRoleARN == "arn:iam:role/omni-edge-test"
    error_message = "The EKS node role ARN must be mapped to the chart's camelCase field"
  }

  assert {
    condition     = module.omni_connect[0].helm_values.omninet.kubeletAWS.servingSigner == "beta.eks.amazonaws.com/app-serving"
    error_message = "The optional EKS serving signer must be propagated"
  }

  assert {
    condition     = module.omni_connect[0].helm_values.omninet.kubeletAWS.nodeIdentity
    error_message = "The optional node identity setting must be propagated"
  }
}

run "enabled_missing_node_agent_repository" {
  command = plan

  variables {
    install_omni_connect = true
    omni_connect = {
      chart = {
        repository = "oci://registry.example.com/charts"
        version    = "0.1.0-test"
        cluster_agent_image = {
          repository = "registry.example.com/castai/omni-cluster-agent"
          tag        = "0.1.0-test"
        }
        node_agent_image = {
          repository = ""
          tag        = "0.1.0-test"
        }
      }
    }
  }

  expect_failures = [terraform_data.omni_connect_configuration]
}
