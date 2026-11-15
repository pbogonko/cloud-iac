variable "tags" {
  type    = map(string)
  default = {
    Name        = "dev network"
    Environment = "dev"
    Owner       = "terraform"
  }
}
module "loadbalancer" {
    source = "../../microservice/lb"
  
}
resource "azurerm_resource_group" "ecommerce-micro-service" {
  name     = "rg-ecommerce-microservices-dev"
  location = "eastus"
}

resource "azurerm_virtual_network" "ecommerce-vnet" {
  name                = "ecommerce-vnet-eastus"
  resource_group_name = azurerm_resource_group.ecommerce-micro-service.name
  location            = azurerm_resource_group.ecommerce-micro-service.location
  address_space       = ["10.0.0.0/16"]
  tags                = var.tags
}

# Subnets
resource "azurerm_subnet" "public-sub" {
  name                 = "dev-public-sub"
  resource_group_name  = azurerm_resource_group.ecommerce-micro-service.name
  virtual_network_name = azurerm_virtual_network.ecommerce-vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "private-sub" {
  name                 = "dev-private-sub"
  resource_group_name  = azurerm_resource_group.ecommerce-micro-service.name
  virtual_network_name = azurerm_virtual_network.ecommerce-vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Network Security Groups
resource "azurerm_network_security_group" "web-sg" {
  name                = "web-sg"
  resource_group_name = azurerm_resource_group.ecommerce-micro-service.name
  location            = azurerm_resource_group.ecommerce-micro-service.location
}

resource "azurerm_network_security_group" "payment-sg" {
  name                = "payment-sg"
  resource_group_name = azurerm_resource_group.ecommerce-micro-service.name
  location            = azurerm_resource_group.ecommerce-micro-service.location
}

resource "azurerm_network_security_group" "backend-sg" {
  name                = "backend-sg"
  resource_group_name = azurerm_resource_group.ecommerce-micro-service.name
  location            = azurerm_resource_group.ecommerce-micro-service.location
}

# Security Rules
resource "azurerm_network_security_rule" "allow-http_from_internet" {
  name                        = "AllowHTTPInternet"
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  priority                    = 100
  network_security_group_name = azurerm_network_security_group.web-sg.name
  resource_group_name         = azurerm_resource_group.ecommerce-micro-service.name
}

resource "azurerm_network_security_rule" "allow-loadbalancer_probe" {
  name                        = "AllowLBProbe"
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "AzureLoadBalancer"
  destination_address_prefix  = "*"
  priority                    = 110
  network_security_group_name = azurerm_network_security_group.web-sg.name
  resource_group_name         = azurerm_resource_group.ecommerce-micro-service.name
}

# Private subnet services only allow inbound traffic from the VNet (microservices communication)
resource "azurerm_network_security_rule" "backend-internal" {
  name                        = "AllowVNetBackend"
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "*"
  priority                    = 100
  network_security_group_name = azurerm_network_security_group.backend-sg.name
  resource_group_name         = azurerm_resource_group.ecommerce-micro-service.name
}

# NSG Subnet Associations (1 NSG per Subnet)
resource "azurerm_subnet_network_security_group_association" "public-sga" {
  subnet_id                 = azurerm_subnet.public-sub.id
  network_security_group_id = azurerm_network_security_group.web-sg.id
}

resource "azurerm_subnet_network_security_group_association" "private-sga" {
  subnet_id                 = azurerm_subnet.private-sub.id
  network_security_group_id = azurerm_network_security_group.backend-sg.id
}

# Public IP (Fixed SKU & Allocation for Standard Load Balancer)
resource "azurerm_public_ip" "public_ip" {
  name                = "frontend-ip"
  allocation_method   = "Static"
  sku                 = "Standard"
  resource_group_name = azurerm_resource_group.ecommerce-micro-service.name
  location            = azurerm_resource_group.ecommerce-micro-service.location
  tags                = var.tags
}

# Correct NIC mapping to the public subnet
resource "azurerm_network_interface" "e-commerce-nic" {
  name                = "e-commerce-nic"
  resource_group_name = azurerm_resource_group.ecommerce-micro-service.name
  location            = azurerm_resource_group.ecommerce-micro-service.location

  ip_configuration {
    name                          = "internal"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip.id
    subnet_id                     = azurerm_subnet.public-sub.id
  }
}

resource "azurerm_network_interface_backend_address_pool_association" "nic_lb_association" {
  network_interface_id    = azurerm_network_interface.e-commerce-nic.id
  ip_configuration_name   = "internal"
  backend_address_pool_id = module.loadbalancer.backend_address_pool_id
}
# Outputs for consumption by other modules
output "location" {
  value = azurerm_resource_group.ecommerce-micro-service.location
}

output "resource_gp_name" {
  value = azurerm_resource_group.ecommerce-micro-service.name
}

output "public_ip_id" {
  value = azurerm_public_ip.public_ip.id
}

output "public_subnet_id" {
  value = azurerm_subnet.public-sub.id
}
output "private_subnet" {
  value = azurerm_subnet.private-sub.id
  
}
output "vnet" {
  value= azurerm_virtual_network.ecommerce-vnet 
}