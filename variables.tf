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

variable "external_cidr" {
  description = "External CIDR for IPAM configuration"
  type        = string
}

variable "pod_cidr" {
  description = "Pod CIDR for network configuration"
  type        = string
}
