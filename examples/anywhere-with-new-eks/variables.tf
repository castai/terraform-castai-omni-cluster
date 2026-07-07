variable "cluster_region" {
  description = "EKS cluster region"
  type        = string
}

variable "cluster_name" {
  description = "Cluster Name"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version used by EKS"
  type        = string
  default     = "1.32"
}

variable "castai_api_url" {
  type        = string
  description = "URL of alternative CAST AI API to be used during development or testing"
  default     = "https://api.cast.ai"
}

variable "kvisor_grpc_url" {
  description = "Kvisor gRPC URL"
  type        = string
  default     = "kvisor.prod-master.cast.ai:443"
}

variable "castai_api_token" {
  description = "Your CAST AI API key"
  type        = string
  sensitive   = true
  default     = "" # add your api key
}

variable "organization_id" {
  description = "Your CAST AI Organization ID"
  type        = string
}

variable "omni_agent_chart_version" {
  description = "OMNI agent helm chart version"
  type        = string
  default     = "1.14.1"
}

variable "storage_provider" {
  description = "Storage provider (storageclass) for the edge clusters. If empty, they will be defaulted to `gp3` for EKS"
  type        = string
  default     = "gp3"
}

variable "loadbalancer_provider" {
  description = "LoadBalancer provider for edge cluster. This setting is used only for EKS clusters (accepted values are `nlb` and `external`). If empty, it will be defaulted to `external` for EKS"
  type        = string
  default     = "external"
}

variable "edge_location_name" {
  description = "Name for the edge location. If not provided, will be auto-generated"
  type        = string
  default     = null
}
