variable "castai_api_token" {
  type      = string
  sensitive = true
}

variable "castai_api_url" {
  type    = string
  default = "https://api.cast.ai"
}

variable "cluster_id" {
  description = "Cast AI cluster ID"
  type = string
}

variable "organization_id" {
  description = "Cast AI organization ID"
  type = string
}
