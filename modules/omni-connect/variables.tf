variable "k8s_provider" {
  description = "Kubernetes cloud provider-specific storage and virtual node defaults"
  type        = string

  validation {
    condition     = contains(["gke", "eks", "aks"], var.k8s_provider)
    error_message = "Kubernetes provider must be one of: gke, eks, aks"
  }
}

variable "namespace" {
  description = "Namespace that already contains the omni-agent and can also host Omni-Connect"
  type        = string
}

variable "storage_provider" {
  description = "Default storage class inherited from the parent module"
  type        = string
  default     = null
}

variable "skip_helm" {
  description = "Only compute values for GitOps instead of creating a Helm release"
  type        = bool
  default     = false
}

variable "castai" {
  description = "Cast AI API settings for backend-labelled join commands. api_key is passed to the chart for a dedicated Secret instead of referencing an existing Secret."
  type = object({
    api_url         = string
    organization_id = string
    cluster_id      = string
    api_key         = string
  })
  default   = null
  sensitive = true

  validation {
    condition     = var.castai == null || alltrue([for value in [var.castai.api_key, var.castai.api_url, var.castai.organization_id, var.castai.cluster_id] : trimspace(value) != ""])
    error_message = "castai.api_key, castai.api_url, castai.organization_id and castai.cluster_id must not be empty when Cast AI is configured."
  }
}

variable "omni_connect" {
  description = "Omni-Connect chart, images, and networking configuration"
  type = object({
    chart = object({
      repository          = string
      name                = optional(string, "omni-connect")
      version             = string
      cluster_agent_image = object({ repository = string, tag = string })
      node_agent_image    = object({ repository = string, tag = string })
    })
    public_url       = optional(string)
    cidr             = optional(string, "100.127.0.0/16")
    cloud_cidrs      = optional(list(string), [])
    storage_provider = optional(string)
    virtual_nodes    = optional(bool)
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
  default = null
}
