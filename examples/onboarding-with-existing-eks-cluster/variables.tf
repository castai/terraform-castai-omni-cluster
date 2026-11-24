variable "eks_cluster_region" {
  description = "EKS cluster region"
  type        = string
}

variable "eks_cluster_name" {
  description = "EKS Cluster Name"
  type        = string
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

variable "organization_id" {
  description = "Cast AI Organization ID"
  type        = string
}

variable "cluster_id" {
  description = "Cast AI Cluster ID"
  type        = string
}

variable "storage_provider" {
  description = "Storage provider (storageclass) for the edge clusters. If empty, they will be defaulted to `gp3` for EKS"
  type        = string
  default     = null
}

variable "loadbalancer_provider" {
  description = "LoadBalancer provider for edge cluster. This setting is used only for EKS clusters (accepted values are `nlb` and `external`). If empty, it will be defaulted to `external` for EKS"
  type        = string
  default     = null
}

variable "skip_helm" {
  description = "Skip installing any helm release; allows managing helm releases using GitOps"
  type        = bool
  default     = false
}

variable "edge_location_name" {
  description = "Name for the edge location. If not provided, will be auto-generated"
  type        = string
  default     = null
}

variable "install_omni_connect" {
  description = "Install Omni-Connect and its self-hosted control plane"
  type        = bool
  default     = false
}

variable "omni_connect" {
  description = "Omni-Connect chart and node-agent configuration"
  type = object({
    chart = object({
      repository          = string
      version             = string
      cluster_agent_image = object({ repository = string, tag = string })
      node_agent_image    = object({ repository = string, tag = string })
    })
    public_url       = optional(string)
    cidr             = optional(string)
    storage_provider = optional(string)
    virtual_nodes    = optional(bool)
    kubelet_aws = optional(object({
      node_role_arn  = optional(string)
      cluster_name   = optional(string)
      serving_signer = optional(string)
      rbac_group     = optional(string)
      node_identity  = optional(bool, false)
    }))
    helm_values = optional(any)
  })
  default = null
}
