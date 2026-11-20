resource "aws_key_pair" "edge" {
  key_name   = var.name
  public_key = var.ssh_public_key
}

data "aws_vpc" "edge_default" {
  default = true
}

data "aws_subnets" "edge_default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.edge_default.id]
  }
}

resource "aws_security_group" "edge" {
  name   = var.name
  vpc_id = data.aws_vpc.edge_default.id

  # Lock this down to your own address for anything longer lived than a demo.
  ingress {
    description = "ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

resource "aws_instance" "edge" {
  for_each = { for edge in var.edges : edge.name => edge }

  ami                    = data.aws_ami.ubuntu.id
  instance_type          = coalesce(each.value.instance_type, var.default_instance_type)
  key_name               = aws_key_pair.edge.key_name
  subnet_id              = data.aws_subnets.edge_default.ids[0]
  vpc_security_group_ids = [aws_security_group.edge.id]
  # The join command dials the cluster's control plane over this address.
  associate_public_ip_address = true

  root_block_device {
    volume_size = var.boot_disk_size
  }

  tags = { Name = each.key }
}
