# =============================================================================
# Linode edge compute node
#
# A Linode compute instance registered as a Cast AI edge agent. The startup
# script fetches the edge initd script from the Cast AI API and runs it,
# onboarding the node to the configured edge location.
#
# SSH access: public IP assigned by default + authorized_keys via linode_sshkey.
# Startup script: delivered through the Linode Metadata service
#   (metadata.user_data, base64-encoded).
# =============================================================================

# Register the SSH public key with the Linode account so it can be referenced
# by the instance. Reusing the registered key keeps authorized_keys stable
# across instance replacements.
resource "linode_sshkey" "main" {
  label   = "${var.cluster_name}-linode-edge-key"
  ssh_key = var.ssh_public_key
}

resource "linode_instance" "main" {
  label  = "${var.cluster_name}-linode-edge"
  region = var.linode_region
  type   = var.linode_instance_type
  image  = var.linode_image

  # Private IPv4 address. When true, Linode assigns a private IPv4 address
  # (VPC/local network) in addition to the public IP. The public IP is still
  # allocated by default (we do not set `public_ip_type = "none"`).
  private_ip = true

  # SSH: at least one of root_pass / authorized_keys / authorized_users is
  # required when `image` is set. We inject the registered public key.
  authorized_keys = [linode_sshkey.main.ssh_key]

  tags = ["castai-omni", "edge"]

  # Cast AI edge onboarding script delivered via the Linode Metadata service.
  # The payload is a #cloud-config document, base64-encoded as required by
  # metadata.user_data. The runcmd block fetches the edge initd script from
  # the Cast AI API and pipes it to bash, registering this node as an edge
  # agent for the configured edge location.
  #
  # All values are sourced from existing Terraform variables and module/resource
  # outputs — no hardcoded secrets.
  metadata {
    user_data = base64encode(<<-EOT
      #cloud-config
      runcmd:
        - |
          set -e
          API_HOST="${var.castai_api_url}"
          API_KEY="${var.castai_api_token}"
          ORG_ID="${module.castai_aks.organization_id}"
          CLUSTER_ID="${module.castai_aks.cluster_id}"
          LOC_ID="${castai_edge_location.custom_location.id}"

          curl --url "$${API_HOST}/omni-provisioner/v1beta/organizations/$${ORG_ID}/clusters/$${CLUSTER_ID}/edge-locations/$${LOC_ID}:edgeInitdScript" \
               --header "X-API-Key: $${API_KEY}" \
               --header 'content-type: application/json' | \
               INITD_KUBERNETES_LABELS="autoscaling.cast.ai/removal-disabled=true" \
               bash
    EOT
    )
  }

  # The edge location must exist before the node can register with it.
  depends_on = [castai_edge_location.custom_location]
}

output "linode_node_public_ip" {
  description = "Public IPv4 address of the Linode edge compute instance (use for SSH)."
  # `ipv4` contains both public and private addresses when private_ip is
  # enabled. We filter out the private address to isolate the public one.
  value = one([for ip in linode_instance.main.ipv4 : ip if ip != linode_instance.main.private_ip_address])
}

output "linode_node_private_ip" {
  description = "Private IPv4 address of the Linode edge compute instance (VPC/local network)."
  value       = linode_instance.main.private_ip_address
}

# =============================================================================
# Edge node readiness synchronization point
#
# Waits for the Linode edge node to join the AKS cluster and reach Ready
# status before downstream resources (http_server.tf, etc.) are created.
# Uses kubectl with credentials from the azurerm provider (no external
# kubeconfig file or az CLI call needed). A bash trap cleans up the temp
# cert files on exit.
# =============================================================================

resource "null_resource" "wait_for_edge_node_ready" {
  depends_on = [linode_instance.main, azurerm_kubernetes_cluster.aks]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]

    environment = {
      KUBE_HOST = azurerm_kubernetes_cluster.aks.kube_config[0].host
      KUBE_CA   = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].cluster_ca_certificate)
      KUBE_CERT = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].client_certificate)
      KUBE_KEY  = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].client_key)
    }

    command = <<-EOT
      set -e

      TMP_DIR=$(mktemp -d)
      trap 'rm -rf "$TMP_DIR"' EXIT

      printf '%s' "$KUBE_CA"   > "$TMP_DIR/ca.crt"
      printf '%s' "$KUBE_CERT" > "$TMP_DIR/client.crt"
      printf '%s' "$KUBE_KEY"  > "$TMP_DIR/client.key"

      chmod 600 "$TMP_DIR/client.key"

      RETRY_COUNT=40
      POOLING_INTERVAL=30

      for i in $(seq 1 $RETRY_COUNT); do
        sleep $POOLING_INTERVAL
        READY=$(kubectl \
          --server="$KUBE_HOST" \
          --certificate-authority="$TMP_DIR/ca.crt" \
          --client-certificate="$TMP_DIR/client.crt" \
          --client-key="$TMP_DIR/client.key" \
          get nodes -l omni.cast.ai/edge-node=true --no-headers 2>/dev/null | awk '$2 == "Ready" {print $1}')
        if [ -n "$READY" ]; then
          echo "Edge node is Ready: $READY"
          exit 0
        fi
        echo "Attempt $i/$RETRY_COUNT: edge node not ready yet..."
      done

      echo "Edge node not ready after 20 minutes"
      exit 1
    EOT
  }
}
