# Onboarding an existing EKS cluster

This example installs the existing Omni/Liqo resources and can optionally deploy the self-hosted Omni-Connect control plane in `castai-omni`.

## Optional Omni-Connect

The installation is disabled by default. Enable it only with an explicit compatible chart and image selection:

```hcl
install_omni_connect = true
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
  virtual_nodes = true
}
```

EKS uses virtual nodes and kubelet proxy token authentication by default. Keep virtual nodes enabled unless your Kubernetes fabric CIDR is routed correctly in the VPC. Use `storage_provider` when the default `gp3` storage class is unsuitable, and `kubelet_aws` for EKS-specific authentication. The control plane is exposed with a LoadBalancer; set `public_url` only to override the externally reachable address.

## Verification

After applying, wait for the control-plane Deployment and PostgreSQL storage to become ready. Verify the control-plane Service has an external ingress, then create a short-lived join request:

```sh
kubectl apply -f - <<'EOF'
apiVersion: omni.cast.ai/v1alpha1
kind: OmninetJoinRequest
metadata:
  name: onboarding-smoke-check
  namespace: castai-omni
spec:
  ttl: 10m
EOF
kubectl -n castai-omni get omninetjoinrequest onboarding-smoke-check --watch
```

The request must reach `Ready`. Delete it afterward with `kubectl -n castai-omni delete omninetjoinrequest onboarding-smoke-check`. This check creates no VM or autoscaling workflow.
