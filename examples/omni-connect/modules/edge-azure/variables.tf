variable "name" {
  description = "Prefix for the edge vnet and nsg resources"
  type        = string
}

variable "resource_group" {
  description = "Resource group created for the edges"
  type        = string
}

variable "location" {
  description = "Region for the edge resource group and VMs - pick a far away one, that is the point"
  type        = string
}

variable "address_space" {
  description = "Address space of the edge vnet"
  type        = list(string)
  default     = ["10.30.0.0/24"]
}

variable "ssh_public_key" {
  description = "Public key installed on every edge VM"
  type        = string
}

variable "default_vm_size" {
  description = "VM size for edges that do not set their own"
  type        = string
  default     = "Standard_D2s_v5"
}

variable "boot_disk_size" {
  type    = number
  default = 150
}

variable "edges" {
  description = "Edges to provision: name is the VM and Kubernetes node name"
  type = list(object({
    name = string
    size = optional(string)
  }))
}
