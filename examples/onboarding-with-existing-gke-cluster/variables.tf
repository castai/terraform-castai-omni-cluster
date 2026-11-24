variable "gke_project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "gke_cluster_location" {
  description = "GKE Cluster Location (region or zone)"
  type        = string
}

variable "gke_cluster_name" {
  description = "GKE Cluster Name"
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
      version             = string
      cluster_agent_image = object({ repository = string, tag = string })
      node_agent_image    = object({ repository = string, tag = string })
    })
    public_url       = optional(string)
    cidr             = optional(string)
    storage_provider = optional(string)
    virtual_nodes    = optional(bool)
    helm_values      = optional(any)
  })
  default = null
}
