module "resource_gp" {
    source = "../../microservice"
  
}
module "network" {
    source = "../network"
  
}
resource "azurerm_redis_cache" "redis" {
    name = "redis-cache"
    location = module.resource_gp.location
    sku_name = "Standard"
    resource_group_name = module.resource_gp.resource_gp_name
    capacity = 2
    family = "C"// standard pricing
    minimum_tls_version = "1.2"
    non_ssl_port_enabled = false
    public_network_access_enabled = false
    redis_configuration {
      
    }
}
resource "azurerm_redis_cache_access_policy" "access_policy" {
  name           = "redis-access"
  redis_cache_id = azurerm_redis_cache.redis.id
  permissions    = "+@read +@write +@connection +cluster|info"
}
##private endpoint==> our redis instance sits on a private sub so a private endpoint has to be configured
resource "azurerm_private_endpoint" "redis" {
location = module.resource_gp.location
name = "redis-endpoint"
resource_group_name = module.resource_gp.resource_gp_name
subnet_id = module.network.redis_subnet
private_service_connection {
  name = "private-connection"
  is_manual_connection = false
  subresource_names = ["redisCache"]
  private_connection_resource_id = azurerm_redis_cache.redis.id

}
private_dns_zone_group {
  name                 = "redis-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.redis_dns.id]
}
  
}
#Private DNS Zone for Azure Cache for Redis
resource "azurerm_private_dns_zone" "redis_dns" {
  name                = "privatelink.redis.cache.windows.net"
  resource_group_name = module.resource_gp.resource_gp_name
}
# Link the Private DNS Zone to your VNet so VMs/containers resolve the private IP
resource "azurerm_private_dns_zone_virtual_network_link" "redis_vnet_link" {
  name                  = "redis-vnet-link"
  virtual_network_id    = module.network.vnet_id # Make sure your network module outputs vnet_id
  private_dns_zone_id = azurerm_private_dns_zone.redis_dns.id
}