variable "azure_subscription_id" {
  description = "Azure Subscription ID"
  type        = string
}

variable "aks_cluster_name" {
  description = "AKS Cluster Name"
  type        = string
}

variable "aks_resource_group" {
  description = "Azure Resource Group containing the AKS cluster"
  type        = string
}

variable "gke_project_id" {
  description = "GCP Project ID of an edge location"
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
  description = "Omni-Connect chart and networking configuration"
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
