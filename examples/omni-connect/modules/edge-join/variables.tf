variable "edges" {
  description = "Edges to join: name is the Kubernetes node name, public_ip and ssh_user reach the VM"
  type = list(object({
    name      = string
    public_ip = string
    ssh_user  = string
  }))
}

variable "kubeconfig_path" {
  description = "Kubeconfig the join step uses to talk to the cluster; the edge VM cannot reach it"
  type        = string
}

variable "ssh_key_path" {
  description = "Private key matching the public keys installed on the edge VMs"
  type        = string
}

variable "known_hosts_path" {
  description = "Where to record the edge VM host keys"
  type        = string
  default     = null
}

variable "namespace" {
  description = "Namespace the omninet control plane and the join requests live in"
  type        = string
  default     = "castai-omni"
}

variable "join_ttl" {
  description = "TTL of the join request the step creates"
  type        = string
  default     = "2h"
}

variable "dependencies" {
  description = "Resource ids (chart release, kubeconfig file) the join must wait for"
  type        = list(string)
  default     = []
}
