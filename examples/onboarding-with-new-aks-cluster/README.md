# Onboarding a new AKS cluster with Cast AI Omni

This example creates a new Azure AKS cluster, onboards it to CAST AI Omni, provisions a Linode edge node, and deploys latency monitoring with Prometheus and Grafana.

- **AKS cluster** — created in an Azure resource group with kubenet networking
- **Cast AI onboarding** — `castai/aks` module registers the cluster and creates the Azure AD app
- **Custom edge location** — `castai_edge_location` with a `custom` block
- **Linode edge node** — VM running the Cast AI edge agent, joining the AKS cluster as a virtual node
- **HTTP server** — nginx deployment on the edge node for latency measurement
- **Blackbox exporter** — probes the edge HTTP server, exposing `probe_duration_seconds` to Prometheus
- **Prometheus + Grafana** — kube-prometheus-stack Helm release with a pre-provisioned "Edge HTTP Latency" dashboard

## Prerequisites

- Azure subscription with vCPU quota for the chosen region
- Linode account and API token
- CAST AI API token and organization ID
- `terraform >= 1.10`
- `kubectl` and `az` CLI installed locally

## Usage

1. Copy the vars file and fill in your values:

   ```bash
   cp tf.vars.example terraform.tfvars
   ```

2. Initialize and apply:

   ```bash
   terraform init
   terraform apply
   ```

3. What gets deployed and where:

   **On the AKS cluster:**
   - `castai-agent` namespace — CAST AI agent, cluster controller, evictor, spot handler (via `castai/aks` module)
   - `castai-omni` namespace — Omni agent + Liqo for multi-cluster networking (via `castai/omni-cluster` root module)
   - `latency` namespace — nginx HTTP server (on the Linode edge node), blackbox exporter (on regular AKS nodes), and a ClusterIP service
   - `monitoring` namespace — Prometheus, Grafana, Alertmanager, node-exporter (via `kube-prometheus-stack` Helm release)

   **On the Linode edge node:**
   - Cast AI edge agent (via the `edgeInitdScript` onboarding script in cloud-init)
   - The node joins the AKS cluster as a virtual node (Liqo offloading)
   - nginx HTTP server pod is scheduled here via `nodeSelector: omni.cast.ai/edge-node=true`

4. Access Grafana:

   ```bash
   # Get admin credentials
   kubectl get secret -n monitoring kube-prometheus-stack-grafana \
     -o jsonpath='{.data.admin-password}' | base64 -d; echo

   # Port-forward to localhost
   kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
   ```

   Open http://localhost:3000, log in with username `admin` and the password from above. The "Edge HTTP Latency" dashboard shows round-trip latency from AKS nodes to the Linode edge node.

## Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `cluster_region` | Azure location (e.g. `westeurope`) | Yes |
| `cluster_name` | AKS cluster name | Yes |
| `azure_subscription_id` | Azure subscription ID | Yes |
| `castai_api_token` | CAST AI API token | Yes |
| `organization_id` | CAST AI organization ID | Yes |
| `linode_token` | Linode API token | Yes |
| `linode_region` | Linode region (e.g. `us-central`) | Yes |
| `ssh_public_key` | SSH public key for the Linode instance | Yes |
| `custom_edge_location_region` | Region for the custom edge location | Yes |
| `aks_node_vm_size` | VM size for AKS nodes (default: `Standard_D2as_v5`) | No |
| `aks_node_count` | Number of AKS nodes (default: `2`) | No |
| `linode_instance_type` | Linode plan (default: `g6-standard-4`) | No |

## Cleanup

```bash
terraform destroy
```
