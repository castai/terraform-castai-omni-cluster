variable "name" {
  description = "Prefix for the edge key pair and security group"
  type        = string
}

variable "ssh_public_key" {
  description = "Public key installed on every edge VM"
  type        = string
}

variable "default_instance_type" {
  description = "Instance type for edges that do not set their own"
  type        = string
  default     = "t3.large"
}

variable "boot_disk_size" {
  type    = number
  default = 150
}

variable "edges" {
  description = "Edges to provision: name is the VM and Kubernetes node name"
  type = list(object({
    name          = string
    instance_type = optional(string)
  }))
}
