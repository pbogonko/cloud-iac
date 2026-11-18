
variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "public_ip_id" {
  type = string
}

resource "azurerm_lb" "web_lb" {
  name                = "web-lb"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "frontendIP"
    public_ip_address_id = var.public_ip_id
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

# Forward public HTTP traffic to the backend pool.
resource "azurerm_lb_rule" "web-http" {
  name                           = "http-rule"
  loadbalancer_id                = azurerm_lb.web_lb.id
  frontend_ip_configuration_name = "frontendIP"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.backend-pool.id]
  probe_id                       = azurerm_lb_probe.web-lb-probe.id
}

output "web_lb_id" {
  value = azurerm_lb.web_lb.id
}
output "backend_address_pool_id" {
  value = azurerm_lb_backend_address_pool.backend-pool.id

}