variable "cluster_region" {
  description = "Azure location for the AKS cluster (e.g. East US, West Europe)."
  type        = string
}

variable "cluster_name" {
  description = "AKS Cluster Name"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version for the AKS cluster. Set to null to let Azure pick the default supported version for the region. Check available versions with: az aks get-versions -l <region>"
  type        = string
  default     = null
}

variable "azure_subscription_id" {
  description = "Azure Subscription ID used to authenticate the azurerm provider."
  type        = string
  sensitive   = true
}

variable "aks_node_vm_size" {
  description = "VM size for the AKS default node pool."
  type        = string
  default     = "Standard_D2as_v5"
}

variable "aks_node_count" {
  description = "Number of nodes in the AKS default node pool."
  type        = number
  default     = 4
}

variable "castai_api_url" {
  description = "Cast AI API URL"
  type        = string
  default     = "https://api.cast.ai"
}

variable "kvisor_grpc_url" {
  description = "Kvisor gRPC URL"
  type        = string
  default     = "kvisor.prod-master.cast.ai:443"
}

variable "castai_api_token" {
  description = "Cast AI API Token"
  type        = string
  sensitive   = true
}

variable "skip_helm" {
  description = "Skip installing any helm release; allows managing helm releases using GitOps"
  type        = bool
  default     = false
}

variable "tags" {
  type        = map(any)
  description = "Optional tags for new cluster nodes. This parameter applies only to new nodes - tags for old nodes are not reconciled."
  default     = {}
}

variable "custom_edge_location_region" {
  description = "Region for the custom edge location."
  type        = string
}

variable "linode_token" {
  description = "Linode APIv4 Personal Access Token used to authenticate the Linode provider."
  type        = string
  sensitive   = true
}

variable "linode_region" {
  description = "Linode region where the edge compute instance is created (e.g. us-central, eu-central-1)."
  type        = string
}

variable "linode_instance_type" {
  description = "Linode instance plan/type for the edge compute node."
  type        = string
}

variable "linode_image" {
  description = "Linode image for the edge compute instance."
  type        = string
  default     = "linode/ubuntu22.04"
}

variable "ssh_public_key" {
  description = "OpenSSH public key string injected into the Linode instance for SSH access (e.g. ssh-ed25519 AAAA... user@host)."
  type        = string
  sensitive   = true
}
