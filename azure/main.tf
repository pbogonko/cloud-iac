
resource "azurerm_resource_group" "ecommerce-micro-service" {
  name     = "shopify-ms"
  location = "East US"
  tags = {
    Name        = "dev resource group"
    Environment = "dev"
    Owner       = "terraform"
  }
}

module "network" {
  source              = "./network"
  resource_group_name = azurerm_resource_group.ecommerce-micro-service.name
  location            = azurerm_resource_group.ecommerce-micro-service.location
  tags                = var.tags
}

module "loadbalancer" {
  source              = "./lb"
  location            = azurerm_resource_group.ecommerce-micro-service.location
  resource_group_name = azurerm_resource_group.ecommerce-micro-service.name
  public_ip_id        = module.network.public_ip_id
}

module "rds" {
  source                 = "./rds"
  location               = azurerm_resource_group.ecommerce-micro-service.location
  resource_group_name    = azurerm_resource_group.ecommerce-micro-service.name
  postgres_subnet_id     = module.network.postgres_subnet
  vnet_id                = module.network.vnet_id
  administrator_password = var.postgres_administrator_password
}

module "redis" {
  source              = "./redis"
  location            = azurerm_resource_group.ecommerce-micro-service.location
  resource_group_name = azurerm_resource_group.ecommerce-micro-service.name
  redis_subnet_id     = module.network.redis_subnet
  vnet_id             = module.network.vnet_id
}

module "acr" {
  source                    = "./acr"
  location                  = azurerm_resource_group.ecommerce-micro-service.location
  resource_group_name       = azurerm_resource_group.ecommerce-micro-service.name
  registry_name             = var.acr_registry_name
  key_vault_name            = var.acr_key_vault_name
  replication_locations     = var.acr_replication_locations
  private_endpoint_subnet_id = module.network.acr_subnet
  vnet_id                   = module.network.vnet_id
}

# e commerce NIC 1
resource "azurerm_network_interface" "e-commerce-nic-1" {
  name                = "e-commerce-nic-1"
  resource_group_name = azurerm_resource_group.ecommerce-micro-service.name
  location            = azurerm_resource_group.ecommerce-micro-service.location

  ip_configuration {
    name                          = "internal"
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = module.network.public_subnet_id
  }
}
resource "azurerm_network_interface" "sales-nic" {
  name                = "sales-nic"
  resource_group_name = azurerm_resource_group.ecommerce-micro-service.name
  location            = azurerm_resource_group.ecommerce-micro-service.location

  ip_configuration {
    name                          = "internal"
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = module.network.private_subnet
  }
}
#  E-Commerce Virtual Machine one
resource "azurerm_linux_virtual_machine" "e-commerce-vm" {
  name                  = "e-commerce-vm-1"
  resource_group_name   = azurerm_resource_group.ecommerce-micro-service.name
  location              = azurerm_resource_group.ecommerce-micro-service.location
  size                  = "Standard_B1s"
  admin_username        = var.admin_username
  network_interface_ids = [azurerm_network_interface.e-commerce-nic-1.id]
  admin_ssh_key {
    # Expand the user path and ensure the key username matches the VM administrator.
    username   = var.admin_username
    public_key = file(pathexpand(var.ssh_public_key_path))
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

# Attach the public VM NIC to the load balancer backend pool.
resource "azurerm_network_interface_backend_address_pool_association" "ecommerce_lb" {
  network_interface_id    = azurerm_network_interface.e-commerce-nic-1.id
  ip_configuration_name   = "internal"
  backend_address_pool_id = module.loadbalancer.backend_address_pool_id
}

# Sales Virtual Machine 
resource "azurerm_linux_virtual_machine" "e-commerce-sales" {
  name                  = "sales-vm"
  size                  = "Standard_B1s"
  location              = azurerm_resource_group.ecommerce-micro-service.location
  resource_group_name   = azurerm_resource_group.ecommerce-micro-service.name
  network_interface_ids = [azurerm_network_interface.sales-nic.id]
  admin_username        = var.admin_username

  admin_ssh_key {
    # Reuse the same validated administrator identity and expanded public-key path.
    username   = var.admin_username
    public_key = file(pathexpand(var.ssh_public_key_path))
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

