variable "gke_project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "gke_cluster_location" {
  description = "GKE Cluster Location"
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
