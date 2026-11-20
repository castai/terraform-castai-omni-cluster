resource "tls_private_key" "edge" {
  algorithm = "ED25519"
}

resource "local_file" "edge_ssh_key" {
  content         = tls_private_key.edge.private_key_openssh
  filename        = "${path.module}/.edge_ssh_key"
  file_permission = "0600"
}

module "edge" {
  source = "../modules/edge-aws"

  providers = {
    aws = aws.edge
  }

  name           = "${var.cluster_name}-edge"
  ssh_public_key = tls_private_key.edge.public_key_openssh

  edges = [
    { name = "${var.cluster_name}-edge1", instance_type = var.edge_instance_type },
  ]
}

locals {
  edges = module.edge.edges
}
