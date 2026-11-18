output "public_ip" {
  value = module.network.public_ip_id
}

output "location" {
  value = azurerm_resource_group.ecommerce-micro-service.location
}

output "resource_gp_name" {
  value = azurerm_resource_group.ecommerce-micro-service.name
}

output "acr_login_server" {
  value = module.acr.login_server
}