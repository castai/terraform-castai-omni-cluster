terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.16"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }
  }
}

provider "aws" {
  region = var.region
}

# The edge VM lives in another region: same account, no extra setup.
provider "aws" {
  alias  = "edge"
  region = var.edge_region
}

provider "helm" {
  kubernetes {
    host                   = aws_eks_cluster.omni.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.omni.certificate_authority[0].data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      # --output json: the CLI's table formatter breaks exec plugins.
      args = ["eks", "get-token", "--cluster-name", aws_eks_cluster.omni.name, "--region", var.region, "--output", "json"]
    }
  }
}

variable "region" {
  description = "Region for the EKS cluster"
  type        = string
  default     = "us-east-1"
}

variable "edge_region" {
  description = "Region for the edge VM - pick a far away one, that is the point"
  type        = string
  default     = "us-west-2"
}

variable "cluster_name" {
  type    = string
  default = "omni-connect"
}

variable "cluster_nodes" {
  type    = number
  default = 2
}

variable "node_instance_type" {
  type    = string
  default = "t3.large"
}

variable "edge_instance_type" {
  type    = string
  default = "t3.large"
}

variable "chart_version" {
  description = "omni-connect chart version in the demo registry"
  type        = string
  default     = "1.0.11"
}

variable "registry" {
  description = "OCI registry the omni-connect chart and images live in"
  type        = string
  default     = "us-central1-docker.pkg.dev/localenv-andzej/omninet"
}

data "aws_caller_identity" "current" {}

output "edge_ips" {
  description = "Public IPs of the edge VMs by name"
  value       = { for edge in local.edges : edge.name => edge.public_ip }
}

output "kubeconfig_command" {
  description = "Fetch the cluster kubeconfig with this command"
  value       = "aws eks update-kubeconfig --name ${aws_eks_cluster.omni.name} --region ${var.region}"
}

output "ssh_commands" {
  description = "Reach each edge VM over ssh from this module directory"
  value       = { for edge in local.edges : edge.name => "ssh -i .edge_ssh_key -o IdentitiesOnly=yes ${edge.ssh_user}@${edge.public_ip}" }
}

output "greetings_bucket" {
  value = aws_s3_bucket.greetings.id
}
