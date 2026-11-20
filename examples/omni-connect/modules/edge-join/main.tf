locals {
  known_hosts_path = coalesce(var.known_hosts_path, "${path.module}/.edge_known_hosts")
}

# The single-use join request: its status carries the command the edge runs.
resource "null_resource" "edge_join" {
  for_each = { for edge in var.edges : edge.name => edge }

  triggers = merge(
    { for idx, dep in var.dependencies : "dep${idx}" => dep },
    {
      edge     = each.key
      join_req = timestamp()
    }
  )

  provisioner "local-exec" {
    environment = {
      KUBECONFIG  = var.kubeconfig_path
      EDGE_IP     = each.value.public_ip
      SSH_KEY     = var.ssh_key_path
      SSH_USER    = each.value.ssh_user
      EDGE_NAME   = each.key
      KNOWN_HOSTS = local.known_hosts_path
      NAMESPACE   = var.namespace
      JOIN_TTL    = var.join_ttl
    }
    command = <<-EOT
      set -e
      # (Re)create the join request; a consumed one never hands out a command again.
      kubectl -n "$NAMESPACE" delete omninetjoinrequest "$EDGE_NAME" --ignore-not-found --wait=true
      kubectl -n "$NAMESPACE" apply -f - <<YAML
      apiVersion: omni.cast.ai/v1alpha1
      kind: OmninetJoinRequest
      metadata:
        name: $EDGE_NAME
        namespace: $NAMESPACE
      spec:
        ttl: $JOIN_TTL
      YAML
      echo "waiting for the join command..."
      for i in $(seq 1 60); do
        CMD=$(kubectl -n "$NAMESPACE" get omninetjoinrequest "$EDGE_NAME" -o jsonpath='{.status.joinCommand}')
        [ -n "$CMD" ] && break
        sleep 2
      done
      [ -n "$CMD" ] || { echo "no join command appeared"; exit 1; }
      echo "running the join command on the edge VM..."
      # A freshly created VM needs a minute before sshd answers.
      for i in $(seq 1 60); do
      ssh -i "$SSH_KEY" -o IdentitiesOnly=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile="$KNOWN_HOSTS" "$SSH_USER"@"$EDGE_IP" "sudo sh -c '$CMD'" && break
      [ $i -eq 60 ] && { echo "could not reach the edge VM over ssh"; exit 1; }
      sleep 5
      done
      echo "the edge joined; watch it appear with: kubectl get nodes -w"
    EOT
  }
}
