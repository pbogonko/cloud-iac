# postgres setup
module "main" {
    source = "../../microservice"
  
}
module "network" {
    source = "../../microservice/network"
  
}
resource "azurerm_private_dns_zone" "sales" {
  name                = "sales.postgres.database.azure.com"
  resource_group_name = module.main.resource_gp_name
}
resource "azurerm_private_dns_zone_virtual_network_link" "sales_link" {
  name                = "salesVnetZone.com"
  private_dns_zone_id = azurerm_private_dns_zone.sales.id
  virtual_network_id  = module.network.vnet.id
  depends_on          = [module.network.private_subnet]
}
resource "azurerm_postgresql_flexible_server" "sales_db" {
    resource_group_name = module.main.resource_gp_name
    location = module.main.location
    name = "sales-db-server"
    version = "12"
    administrator_login = "adminUser"//should be securely passed
    administrator_password = "admin_password"//should not be hardcoded
    storage_mb   = 32768
    storage_tier = "P4"
    sku_name   = "B_Standard_B1ms"
    private_dns_zone_id = azurerm_private_dns_zone.sales.id
    auto_grow_enabled = true
    delegated_subnet_id = module.network.private_subnet

}

resource "azurerm_postgresql_flexible_server_database" "sales_db" {
     server_id = azurerm_postgresql_flexible_server.sales_db.id
     name = "sales-db"
       collation = "en_US.utf8"
  charset   = "UTF8"
  lifecycle {
    prevent_destroy = true
  }
  
}