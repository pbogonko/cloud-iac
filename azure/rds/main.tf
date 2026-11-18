variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "postgres_subnet_id" {
  type = string
}

variable "vnet_id" {
  type = string
}

variable "administrator_password" {
  type      = string
  sensitive = true
}

# PostgreSQL private DNS zone uses the private-link zone name.
resource "azurerm_private_dns_zone" "sales" {
  name                = "privatelink.postgres.database.azure.com"
  resource_group_name = var.resource_group_name
}

# Link the private DNS zone to the application VNet.
resource "azurerm_private_dns_zone_virtual_network_link" "sales_link" {
  name                  = "sales-postgres-vnet-link"
  private_dns_zone_name = azurerm_private_dns_zone.sales.name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false
  resource_group_name   = var.resource_group_name
}

resource "azurerm_postgresql_flexible_server" "sales_db" {
  resource_group_name           = var.resource_group_name
  location                      = var.location
  name                          = "sales-db-server"
  version                       = "16"
  administrator_login           = "adminUser"
  administrator_password        = var.administrator_password
  storage_mb                    = 32768
  storage_tier                  = "P4"
  sku_name                      = "B_Standard_B1ms"
  private_dns_zone_id           = azurerm_private_dns_zone.sales.id
  delegated_subnet_id           = var.postgres_subnet_id
  public_network_access_enabled = false
  zone                          = "1"
  auto_grow_enabled             = true

  depends_on = [azurerm_private_dns_zone_virtual_network_link.sales_link]
}

resource "azurerm_postgresql_flexible_server_database" "sales_db" {
  server_id = azurerm_postgresql_flexible_server.sales_db.id
  name      = "sales-db"
  collation = "en_US.utf8"
  charset   = "UTF8"

  lifecycle {
    prevent_destroy = true
  }
}
