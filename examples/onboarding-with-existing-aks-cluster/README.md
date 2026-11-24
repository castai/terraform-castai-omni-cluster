# Onboarding an existing AKS cluster

This example installs the existing Omni/Liqo resources and can optionally deploy the self-hosted Omni-Connect control plane in `castai-omni`.

## Optional Omni-Connect

The installation is disabled by default. Enable it with explicit chart and image selections:

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

The database uses the cluster's default storage class unless `storage_provider` is set. EKS-specific virtual-node and token-auth settings are not applied to AKS. Configure `public_url` only if the default LoadBalancer address needs to be overridden.

## Verification

Wait for the control-plane Deployment and PostgreSQL to become ready, then create a time-limited join request:

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

The expected phase is `Ready`. Delete the request afterward with `kubectl -n castai-omni delete omninetjoinrequest onboarding-smoke-check`. If the phase remains `Pending`, check the external control-plane address and agent image configuration.
