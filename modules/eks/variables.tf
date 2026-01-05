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
