variable "cluster_region" {
  description = "EKS cluster region"
  type        = string
}

variable "cluster_name" {
  description = "EKS Cluster Name"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version used by EKS"
  type        = string
  default     = "1.32"
}

variable "castai_api_url" {
  description = "Cast AI API URL"
  type        = string
  default     = "https://api.cast.ai"
}

variable "castai_grpc_url" {
  description = "Cast AI gRPC URL"
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

variable "tags" {
  type        = map(any)
  description = "Optional tags for new cluster nodes. This parameter applies only to new nodes - tags for old nodes are not reconciled."
  default     = {}
}

variable "edge_location_name" {
  description = "Name for the edge location. If not provided, will be auto-generated"
  type        = string
  default     = null
}

variable "google_project_id" {
  type = string
}

variable "oci_tenancy_id" {
  type = string
}

variable "oci_compartment_id" {
  type = string
}

variable "oci_region" {
  type = string
  description = "OCI region where the Omni edge location is created."
}

variable "oci_home_region" {
  type        = string
  description = "OCI home region for IAM resources."
}
