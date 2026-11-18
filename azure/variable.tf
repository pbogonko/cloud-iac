variable "tags" {
  type = map(string)
  default = {
    Environment = "dev"
    Owner       = "Terraform"
  }
}

variable "os" {
  type    = string
  default = "linux"
}

variable "postgres_administrator_password" {
  type      = string
  sensitive = true

  validation {
    condition     = length(var.postgres_administrator_password) >= 12
    error_message = "The PostgreSQL administrator password must contain at least 12 characters."
  }
}

variable "admin_username" {
  type    = string
  default = "adminusername"
}

variable "ssh_public_key_path" {
  type    = string
  default = "~/.azure-key.pub"
}

variable "acr_registry_name" {
  description = "Globally unique lowercase alphanumeric Azure Container Registry name."
  type        = string
}

variable "acr_key_vault_name" {
  description = "Globally unique Azure Key Vault name used for ACR encryption."
  type        = string
}

variable "acr_replication_locations" {
  description = "Optional additional Azure regions for ACR geo-replication."
  type        = list(string)
  default     = []
}