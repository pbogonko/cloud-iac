
#resource group 

resource "azurerm_resource_group" "ecommerce-micro-service" {
    name = "shopify-ms"
    location = "East US"
    tags = {
      Name="dev resource group"
      Environment="dev"
      Owner="terraform"
    }
  
}

module "network" {
    source = "./network"
}
# e commerce NIC 1
resource "azurerm_network_interface" "e-commerce-nic-1" {
  name                = "e-commerce-nic-1"
  resource_group_name = azurerm_resource_group.ecommerce-micro-service.name
  location            = azurerm_resource_group.ecommerce-micro-service.location

  ip_configuration {
    name                          = "internal"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip.id
    subnet_id                     = azurerm_subnet.public-sub.id 
  }
}
resource "azurerm_network_interface" "sales-nic" {
  name                = "sales-nic"
  resource_group_name = azurerm_resource_group.ecommerce-micro-service.name
  location            = azurerm_resource_group.ecommerce-micro-service.location

  ip_configuration {
    name                          = "internal"
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.private-sub.id # Placed securely in private subnet
  }
}
#  E-Commerce Virtual Machine one
resource "azurerm_linux_virtual_machine" "e-commerce-vm" {
  name                  = "e-commerce-vm-1"
  resource_group_name   = azurerm_resource_group.ecommerce-micro-service.name
  location              = azurerm_resource_group.ecommerce-micro-service.location
  size                  = "Standard_B1s"
  admin_username        = "Orionsrv"
  network_interface_ids = [azurerm_network_interface.e-commerce-nic-1.id]
  admin_ssh_key {
    username   = "adminusername"
    public_key = file("~/.azure-key.pub")//ssh key config example
  }
  custom_data = filebase64("customData.tpl") //custom data
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  tags = var.tags
}
# Sales Virtual Machine 
resource "azurerm_linux_virtual_machine" "e-commerce-sales" {
  name                  = "sales-vm"
  size                  = "Standard_B1s"
  location              = azurerm_resource_group.ecommerce-micro-service.location
  resource_group_name   = azurerm_resource_group.ecommerce-micro-service.name
  network_interface_ids = [azurerm_network_interface.sales-nic.id]
  admin_username        = "adminusername"

  admin_ssh_key {
    username   = "adminusername"
    public_key = file("~/.azure-key.pub")
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }
  tags = var.tags
}

