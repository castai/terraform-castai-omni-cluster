output "edges" {
  description = "Provisioned edges: name, public ip and the ssh user to reach them"
  value = [
    for edge in google_compute_instance.edge : {
      name      = edge.name
      public_ip = edge.network_interface[0].access_config[0].nat_ip
      ssh_user  = "ubuntu"
    }
  ]
}
