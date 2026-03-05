variable "cluster_name" {
  description = "AKS cluster name"
  type        = string
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
  description = "List of reserved subnet CIDRs that should not be allocated by Liqo IPAM (e.g. VPC peering CIDRs)"
  type        = list(string)
  default     = []
}
