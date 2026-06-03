variable "cluster_name" {
  description = "GKE cluster name"
  type        = string
}

variable "api_server_address" {
  description = "Kubernetes API server address"
  type        = string
}

variable "pod_cidrs" {
  description = "List of Pod CIDRs for IPAM configuration"
  type        = list(string)
}

variable "service_cidr" {
  description = "Service CIDR for IPAM configuration"
  type        = string
}

variable "reserved_subnet_cidrs" {
  description = "List of subnet CIDRs for IPAM reserved subnets"
  type        = list(string)
}

variable "ipam_pools" {
  description = "Override Liqo IPAM network pools. If not set, defaults to private address space (RFC 1918)"
  type        = list(string)
  default     = null
}

variable "ipam_external_cidr" {
  description = "Override Liqo IPAM externalCIDR. If not set, it will be allocated automatically by Liqo"
  type        = string
  default     = null
}

variable "ipam_internal_cidr" {
  description = "Override Liqo IPAM internalCIDR. If not set, it will be allocated automatically by Liqo"
  type        = string
  default     = null
}
