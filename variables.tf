variable "k8s_provider" {
  description = "Kubernetes cloud provider (gke, eks, aks)"
  type        = string
  validation {
    condition     = contains(["gke", "eks", "aks"], var.k8s_provider)
    error_message = "Kubernetes provider must be one of: gke, eks, aks"
  }
}

variable "api_url" {
  description = "CAST AI API URL"
  type        = string
  default     = "https://api.cast.ai"
}

variable "api_token" {
  description = "CAST AI API token (key) for authentication"
  type        = string
  sensitive   = true
}

variable "organization_id" {
  description = "CAST AI organization ID"
  type        = string
}

variable "cluster_id" {
  description = "CAST AI cluster ID to enable Omni functionality for"
  type        = string
}

variable "cluster_name" {
  description = "CAST AI cluster name"
  type        = string
}

variable "cluster_region" {
  description = "K8s cluster region"
  type        = string
}

variable "cluster_zone" {
  description = "K8s cluster zone"
  type        = string
  default     = ""
}

variable "api_server_address" {
  description = "K8s API server address"
  type        = string
}

variable "pod_cidr" {
  description = "Pod CIDR for network configuration"
  type        = string
}

variable "service_cidr" {
  description = "Service CIDR for network configuration"
  type        = string
}

variable "reserved_subnet_cidrs" {
  description = "List of reserved subnet CIDR's (relevant for GKE)"
  type        = list(string)
  default     = []
}

variable "omni_agent_chart_version" {
  description = "OMNI agent helm chart version"
  type        = string
  default     = "v1.1.6"
}

variable "skip_helm" {
  description = "Skip installing any helm release; allows managing helm releases using GitOps"
  type        = bool
  default     = false
}
