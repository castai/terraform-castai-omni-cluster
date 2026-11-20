variable "name" {
  description = "Prefix for the edge network, subnet and firewall resources"
  type        = string
}

variable "network" {
  description = "Name of an existing network to place the edges in; when null the module creates a dedicated one"
  type        = string
  default     = null
}

variable "region" {
  description = "Region for the edge subnet"
  type        = string
}

variable "subnet_cidr" {
  description = "CIDR for the edge subnet"
  type        = string
  default     = "10.20.0.0/24"
}

variable "ssh_public_key" {
  description = "Public key installed on every edge VM"
  type        = string
}

variable "ssh_source_ranges" {
  description = "Source ranges allowed to reach the edge VMs over ssh"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "default_machine_type" {
  description = "Machine type for edges that do not set their own"
  type        = string
  default     = "n1-standard-4"
}

variable "boot_disk_size" {
  type    = number
  default = 150
}

variable "edges" {
  description = "Edges to provision: name is the VM and Kubernetes node name"
  type = list(object({
    name         = string
    zone         = optional(string)
    machine_type = optional(string)
  }))
}
