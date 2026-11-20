output "edges" {
  description = "Provisioned edges: name, public ip and the ssh user to reach them"
  value = [
    for edge in aws_instance.edge : {
      name      = edge.tags_all["Name"]
      public_ip = edge.public_ip
      ssh_user  = "ubuntu"
    }
  ]
}
