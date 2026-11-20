output "edges" {
  description = "Provisioned edges: name, public ip and the ssh user to reach them"
  value = [
    for edge in azurerm_linux_virtual_machine.edge : {
      name      = edge.name
      public_ip = edge.public_ip_address
      ssh_user  = "azureuser"
    }
  ]
}
