# Onboard an existing EKS cluster with only omni-connect

This example installs **only omni-connect** and its self-hosted control plane on an existing EKS cluster. It does not install omni-agent, Liqo, an EdgeCluster, or an edge-location module.

The module registers the cluster with `provisioning_mode = "NATIVE"` and omits `omni_agent_version`. The standard CAST AI namespace (`castai-agent`) is used by default and can be overridden with `namespace`.

## Configure and run

Configure AWS and Kubernetes/Helm provider credentials for your existing EKS cluster, then supply the chart and both explicitly compatible images:

```hcl
eks_cluster_name    = "<existing-eks-cluster>"
organization_id     = "<cast-ai-organization-id>"
cluster_id          = "<cast-ai-cluster-id>"
castai_api_token    = "<cast-ai-api-token>"
eks_cluster_region  = "us-east-1"

omni_connect = {
  chart = {
    repository = "oci://<chart-registry>"
    version    = "<chart-version>"
    cluster_agent_image = {
      repository = "<registry>/omni-cluster-agent"
      tag        = "<compatible-tag>"
    }
    node_agent_image = {
      repository = "<registry>/omni-node-agent"
      tag        = "<compatible-tag>"
    }
  }
  # Choose a public address reachable from future edges, or customize the service.
  public_url    = "https://omni.example.com"
  virtual_nodes = true
}
```

Then run:

```sh
terraform init
terraform apply
```

`skip_helm` is `false` by default. Set it to `true` to get omni-connect configuration in a GitOps ConfigMap rather than a direct Helm release.

## Verification

Inspect what exists on the cluster: omni-connect must be present under your chosen namespace, while omni-agent must be absent. The control plane and its PostgreSQL storage must be ready, and the control-plane Service must be reachable from future edges.

Optionally create a short-lived join request:

```sh
kubectl apply -f - <<'EOF'
apiVersion: omni.cast.ai/v1alpha1
kind: OmninetJoinRequest
metadata:
  name: onboarding-smoke-check
  namespace: castai-agent
spec:
  ttl: 10m
EOF
kubectl -n castai-agent get omninetjoinrequest onboarding-smoke-check --watch
```

Wait for `Ready`, then delete it:

```sh
kubectl -n castai-agent delete omninetjoinrequest onboarding-smoke-check
```

This verification does not create VMs or provision autoscaling workflows. NATIVE edge locations and native autoscaling are configured separately once the compatible omni-connect provider and backend are in place.
