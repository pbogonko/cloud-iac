resource "azurerm_virtual_network" "ecommerce-vnet" {
  name                = "ecommerce-vnet-eastus"
  resource_group_name = var.resource_group_name
  location            = var.location
  address_space       = ["10.0.0.0/16"]
  tags                = var.tags
}

# Subnets
resource "azurerm_subnet" "public-sub" {
  name                 = "dev-public-sub"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.ecommerce-vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "private-sub" {
  name                 = "dev-private-sub"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.ecommerce-vnet.name
  address_prefixes     = ["10.0.2.0/24"]

}

# PostgreSQL Flexible Server requires a dedicated delegated subnet.
resource "azurerm_subnet" "postgres-sub" {
  name                 = "dev-postgres-sub"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.ecommerce-vnet.name
  address_prefixes     = ["10.0.5.0/24"]

  delegation {
    name = "postgresql-delegation"

    service_delegation {
      name    = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_subnet" "redis-sub" {
  name                 = "dev-redis-sub"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.ecommerce-vnet.name
  address_prefixes     = ["10.0.3.0/24"]
}

resource "azurerm_subnet" "acr-sub" {
  name                 = "dev-acr-sub"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.ecommerce-vnet.name
  address_prefixes     = ["10.0.4.0/24"]
}

# Network Security Groups
resource "azurerm_network_security_group" "web-sg" { //frontend
  name                = "web-sg"
  resource_group_name = var.resource_group_name
  location            = var.location
}

resource "azurerm_network_security_group" "payment-sg" { //payment
  name                = "payment-sg"
  resource_group_name = var.resource_group_name
  location            = var.location
}

resource "azurerm_network_security_group" "backend-sg" { //backend
  name                = "backend-sg"
  resource_group_name = var.resource_group_name
  location            = var.location
}
resource "azurerm_network_security_group" "redis-sg" { //redis
  name                = "redis-sg"
  resource_group_name = var.resource_group_name
  location            = var.location
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
  resource_group_name         = var.resource_group_name
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
  resource_group_name         = var.resource_group_name
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
  resource_group_name         = var.resource_group_name
}

#redis security rule
resource "azurerm_network_security_rule" "allow-redis" {
  name                        = "AllowRedisInternal"
  priority                    = 120
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "6380"        # Standard SSL port for Azure Cache for Redis
  source_address_prefix       = "10.0.2.0/24" //only backend can reach redis
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.redis-sg.name
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
#redis subnet association
resource "azurerm_subnet_network_security_group_association" "redis-sga" {
  subnet_id                 = azurerm_subnet.redis-sub.id
  network_security_group_id = azurerm_network_security_group.redis-sg.id
}


# Public IP (Fixed SKU & Allocation for Standard Load Balancer)
resource "azurerm_public_ip" "public_ip" {
  name                = "frontend-ip"
  allocation_method   = "Static"
  sku                 = "Standard"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
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
output "postgres_subnet" {
  value = azurerm_subnet.postgres-sub.id
}
output "acr_subnet" {
  value = azurerm_subnet.acr-sub.id
}
output "vnet" {
  value = azurerm_virtual_network.ecommerce-vnet
}
output "vnet_id" {
  # Expose the VNet ID explicitly so DNS and private endpoint modules do not pass the whole resource.
  value = azurerm_virtual_network.ecommerce-vnet.id
}
output "redis_subnet" {
  value = azurerm_subnet.redis-sub.id

}