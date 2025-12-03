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