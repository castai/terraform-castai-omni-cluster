variable "image_tag" {
  description = "Docker image tag"
  type        = string
}

variable "cluster_name" {
  description = "GKE cluster name"
  type        = string
}

variable "cluster_region" {
  description = "GKE region for topology labels"
  type        = string
}

variable "cluster_zone" {
  description = "GKE zone for topology labels (optional)"
  type        = string
  default     = ""
}

variable "api_server_address" {
  description = "Kubernetes API server address"
  type        = string
}

variable "pod_cidr" {
  description = "Pod CIDR for IPAM configuration"
  type        = string
}

variable "service_cidr" {
  description = "Service CIDR for IPAM configuration"
  type        = string
}

variable "reserved_subnet_cidrs" {
  description = "List of subnet CIDRs for IPAM reserved subnets"
  type        = list(string)
  default     = []
}
