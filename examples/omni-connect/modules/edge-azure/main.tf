resource "azurerm_resource_group" "edge" {
  name     = var.resource_group
  location = var.location
}

resource "azurerm_virtual_network" "edge" {
  name                = "${var.name}-vnet"
  location            = azurerm_resource_group.edge.location
  resource_group_name = azurerm_resource_group.edge.name
  address_space       = var.address_space
}

resource "azurerm_subnet" "edge" {
  name                 = "default"
  resource_group_name  = azurerm_resource_group.edge.name
  virtual_network_name = azurerm_virtual_network.edge.name
  address_prefixes     = var.address_space
}

resource "azurerm_network_security_group" "edge" {
  name                = "${var.name}-nsg"
  location            = azurerm_resource_group.edge.location
  resource_group_name = azurerm_resource_group.edge.name

  # Lock this down to your own address for anything longer lived than a demo.
  security_rule {
    name                       = "ssh"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_public_ip" "edge" {
  for_each = { for edge in var.edges : edge.name => edge }

  name                = "${each.key}-ip"
  location            = azurerm_resource_group.edge.location
  resource_group_name = azurerm_resource_group.edge.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "edge" {
  for_each = { for edge in var.edges : edge.name => edge }

  name                = "${each.key}-nic"
  location            = azurerm_resource_group.edge.location
  resource_group_name = azurerm_resource_group.edge.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.edge.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.edge[each.key].id
  }
}

resource "azurerm_network_interface_security_group_association" "edge" {
  for_each = { for edge in var.edges : edge.name => edge }

  network_interface_id      = azurerm_network_interface.edge[each.key].id
  network_security_group_id = azurerm_network_security_group.edge.id
}

resource "azurerm_linux_virtual_machine" "edge" {
  for_each = { for edge in var.edges : edge.name => edge }

  name                  = each.key
  location              = azurerm_resource_group.edge.location
  resource_group_name   = azurerm_resource_group.edge.name
  size                  = coalesce(each.value.size, var.default_vm_size)
  network_interface_ids = [azurerm_network_interface.edge[each.key].id]

  admin_username = "azureuser"

  admin_ssh_key {
    username   = "azureuser"
    public_key = var.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = var.boot_disk_size
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  custom_data = base64encode(<<-EOT
    #!/bin/sh
    set -e
    apt-get update || true
  EOT
  )
}
