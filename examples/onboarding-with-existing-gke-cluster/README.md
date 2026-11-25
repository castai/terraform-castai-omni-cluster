# Onboarding an existing GKE cluster

This example installs the existing Omni/Liqo resources and can optionally deploy the self-hosted Omni-Connect control plane in `castai-omni`.

## Optional Omni-Connect

The chart installation is disabled by default. Opt in with an explicit compatible chart and image configuration:

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
}
```

The default database storage class is `premium-rwo`; override `storage_provider` if necessary. EKS-only virtual nodes and kubelet proxy token authentication are disabled for GKE. The control plane uses a LoadBalancer service, or the externally reachable address specified in `public_url`.

## Verification

Wait for both control-plane replicas, PostgreSQL and its PVC to become ready, then run a basic join-request smoke check that creates no additional infrastructure:

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

After the phase reaches `Ready`, remove the smoke-check request using `kubectl -n castai-omni delete omninetjoinrequest onboarding-smoke-check`.
