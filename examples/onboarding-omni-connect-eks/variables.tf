variable "eks_cluster_region" {
  description = "EKS cluster region"
  type        = string
}

variable "eks_cluster_name" {
  description = "Existing EKS cluster name to onboard"
  type        = string
}

variable "castai_api_url" {
  description = "CAST AI API URL"
  type        = string
  default     = "https://api.cast.ai"
}

variable "kvisor_grpc_url" {
  description = "Kvisor gRPC URL"
  type        = string
  default     = "kvisor.prod-master.cast.ai:443"
}

variable "castai_api_token" {
  description = "CAST AI API token"
  type        = string
  sensitive   = true
}

variable "organization_id" {
  description = "CAST AI organization ID"
  type        = string
}

variable "cluster_id" {
  description = "CAST AI cluster ID"
  type        = string
}

variable "namespace" {
  description = "Namespace used for omni-connect"
  type        = string
  default     = "castai-agent"
}

variable "storage_provider" {
  description = "StorageClass for the control-plane PostgreSQL instance. Defaults to gp3 for EKS"
  type        = string
  nullable    = true
  default     = null
}

variable "loadbalancer_provider" {
  description = "Load balancer provider for the control plane service (nlb or external for EKS)"
  type        = string
  nullable    = true
  default     = null
}

variable "skip_helm" {
  description = "Emit the omni-connect configuration in a GitOps ConfigMap instead of creating a Helm release"
  type        = bool
  default     = false
}

variable "omni_connect" {
  description = "Required omni-connect chart, image, and service configuration"
  type = object({
    chart = object({
      repository          = string
      name                = optional(string)
      version             = string
      cluster_agent_image = object({ repository = string, tag = string })
      node_agent_image    = object({ repository = string, tag = string })
    })
    public_url       = optional(string)
    cidr             = optional(string)
    cloud_cidrs      = optional(list(string), [])
    storage_provider = optional(string)
    virtual_nodes    = optional(bool, true)
    kubelet_aws = optional(object({
      node_role_arn   = optional(string)
      cluster_name    = optional(string)
      username_prefix = optional(string)
      serving_signer  = optional(string)
      rbac_group      = optional(string)
      node_identity   = optional(bool, false)
    }))
    service = optional(object({
      type        = optional(string)
      annotations = optional(map(string))
    }))
    helm_values = optional(any)
  })
}
