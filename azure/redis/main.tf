variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "redis_subnet_id" {
  type = string
}

variable "vnet_id" {
  type = string
}

# Redis is private-only and accepts TLS-only connections.
resource "azurerm_redis_cache" "redis" {
  name                          = "redis-cache"
  location                      = var.location
  sku_name                      = "Standard"
  resource_group_name           = var.resource_group_name
  capacity                      = 2
  family                        = "C"
  minimum_tls_version           = "1.2"
  non_ssl_port_enabled          = false
  public_network_access_enabled = false

  redis_configuration {}
}

# The access policy grants application read/write and connection operations.
resource "azurerm_redis_cache_access_policy" "access_policy" {
  name           = "redis-access"
  redis_cache_id = azurerm_redis_cache.redis.id
  permissions    = "+@read +@write +@connection +cluster|info"
}

# Create a private endpoint in the dedicated Redis subnet.
resource "azurerm_private_endpoint" "redis" {
  location            = var.location
  name                = "redis-endpoint"
  resource_group_name = var.resource_group_name
  subnet_id           = var.redis_subnet_id

  private_service_connection {
    name                           = "private-connection"
    is_manual_connection           = false
    subresource_names              = ["redisCache"]
    private_connection_resource_id = azurerm_redis_cache.redis.id
  }

  private_dns_zone_group {
    name                 = "redis-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.redis_dns.id]
  }
}

resource "azurerm_private_dns_zone" "redis_dns" {
  name                = "privatelink.redis.cache.windows.net"
  resource_group_name = var.resource_group_name
}

# Link Redis private DNS to the application VNet.
resource "azurerm_private_dns_zone_virtual_network_link" "redis_vnet_link" {
  name                  = "redis-vnet-link"
  virtual_network_id    = var.vnet_id
  private_dns_zone_name = azurerm_private_dns_zone.redis_dns.name
  registration_enabled  = false
  resource_group_name   = var.resource_group_name
}
