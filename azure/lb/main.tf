
module "network" {
  source = "../../microservice"
}

resource "azurerm_lb" "web_lb" {
  name                = "web-lb"
  location            = module.network.location
  resource_group_name = module.network.resource_gp_name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "frontendIP"
    public_ip_address_id = module.network.public_ip
}
}

resource "azurerm_lb_backend_address_pool" "backend-pool" {
  name            = "backend_pool"
  loadbalancer_id = azurerm_lb.web_lb.id
}

resource "azurerm_lb_probe" "web-lb-probe" {
  name            = "http-probe"
  protocol        = "Tcp"
  port            = 80
  loadbalancer_id = azurerm_lb.web_lb.id
}

output "web_lb_id" {
  value = azurerm_lb.web_lb.id
}
output "backend_address_pool_id" {
    value = azurerm_lb_backend_address_pool.backend-pool.id
  
}