#outputs

output "public-ip" {
    value ="${azurerm_linux_virtual_machine.e-commerce-vm.name}:${data.azurerm_public_ip.public_ip.name}"
    
  
}
output "location" {
    value= azurerm_resource_group.ecommerce-micro-service.location  
}
output "resource_gp_name" {
    value=azurerm_resource_group.ecommerce-micro-service.name
  
}
output "public_ip" {
    value = data.azurerm_public_ip.public_ip.id
  
}