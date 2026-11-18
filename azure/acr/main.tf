variable "location" {
  description = "Azure region for the registry and its supporting resources."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group for the registry and its supporting resources."
  type        = string
}

variable "registry_name" {
  description = "Globally unique Azure Container Registry name."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{5,50}$", var.registry_name))
    error_message = "The registry name must be 5-50 lowercase letters or digits."
  }
}

variable "key_vault_name" {
  description = "Globally unique Key Vault name for the registry encryption key."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9-]{1,22}[a-zA-Z0-9]$", var.key_vault_name))
    error_message = "The Key Vault name must be 3-24 letters, digits, or hyphens."
  }
}

variable "replication_locations" {
  description = "Optional additional Azure regions for registry geo-replication."
  type        = list(string)
  default     = []
}

variable "private_endpoint_subnet_id" {
  description = "Subnet ID where the registry private endpoint will be created."
  type        = string
}

variable "vnet_id" {
  description = "VNet ID linked to the registry private DNS zone."
  type        = string
}

data "azurerm_client_config" "current" {}

resource "azurerm_user_assigned_identity" "acr_identity" {
  name                = "acr-identity"
  resource_group_name = var.resource_group_name
  location            = var.location
}

resource "azurerm_key_vault" "acr_key_vault" {
  name                       = var.key_vault_name
  location                   = var.location
  resource_group_name        = var.resource_group_name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  purge_protection_enabled   = true
  soft_delete_retention_days = 90
  enable_rbac_authorization  = true
}

resource "azurerm_key_vault_key" "acr_key" {
  name         = "acr-encryption-key"
  key_vault_id = azurerm_key_vault.acr_key_vault.id
  key_type     = "RSA"
  key_size     = 2048
  key_opts     = ["wrapKey", "unwrapKey"]
}

# Grant the registry identity the Key Vault role required to use its CMK.
resource "azurerm_role_assignment" "acr_key_access" {
  scope                = azurerm_key_vault.acr_key_vault.id
  role_definition_name = "Key Vault Crypto Service Encryption User"
  principal_id         = azurerm_user_assigned_identity.acr_identity.principal_id
}

resource "azurerm_container_registry" "ecommerce" {
  name                          = var.registry_name
  location                      = var.location
  resource_group_name           = var.resource_group_name
  sku                           = "Premium"
  admin_enabled                 = false
  public_network_access_enabled = false

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.acr_identity.id]
  }

  dynamic "georeplications" {
    for_each = toset(var.replication_locations)
    content {
      location = georeplications.value
    }
  }

  encryption {
    key_vault_key_id   = azurerm_key_vault_key.acr_key.id
    identity_client_id = azurerm_user_assigned_identity.acr_identity.client_id
  }

  depends_on = [azurerm_role_assignment.acr_key_access]
}

resource "azurerm_private_dns_zone" "acr" {
  name                = "privatelink.azurecr.io"
  resource_group_name = var.resource_group_name
}

resource "azurerm_private_dns_zone_virtual_network_link" "acr" {
  name                  = "acr-vnet-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.acr.name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false
}

# With public network access disabled, workloads reach ACR through this endpoint.
resource "azurerm_private_endpoint" "acr" {
  name                = "acr-private-endpoint"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "acr-private-connection"
    private_connection_resource_id = azurerm_container_registry.ecommerce.id
    is_manual_connection           = false
    subresource_names              = ["registry"]
  }

  private_dns_zone_group {
    name                 = "acr-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.acr.id]
  }
}

output "registry_id" {
  value = azurerm_container_registry.ecommerce.id
}

output "login_server" {
  value = azurerm_container_registry.ecommerce.login_server
}
