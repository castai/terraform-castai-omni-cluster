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
}

variable "liqo_chart_version" {
  description = "Liqo helm chart version"
  type        = string
  default     = "v1.0.1-5"
}

variable "api_server_address" {
  description = "K8s API server address"
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

variable "service_cidr" {
  description = "Service CIDR for network configuration"
  type        = string
}

variable "reserved_subnet_cidrs" {
  description = "List of reserved subnet CIDR's"
  type        = list(string)
}
