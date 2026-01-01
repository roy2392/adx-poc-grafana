# ==============================================================================
# Data Sources
# ==============================================================================

data "azurerm_client_config" "current" {}

# ==============================================================================
# Random Suffix for Unique Names
# ==============================================================================

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# ==============================================================================
# Resource Group
# ==============================================================================

resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location

  tags = merge(var.tags, {
    Environment = var.environment
  })
}

# ==============================================================================
# Key Vault
# ==============================================================================

resource "azurerm_key_vault" "main" {
  name                = "kv-adx-${random_string.suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  purge_protection_enabled   = false
  soft_delete_retention_days = 7

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = ["Get", "List", "Set", "Delete", "Purge", "Recover"]
  }

  tags = var.tags
}

# Store Grafana password in Key Vault
resource "azurerm_key_vault_secret" "grafana_password" {
  name         = "grafana-admin-password"
  value        = var.grafana_admin_password
  key_vault_id = azurerm_key_vault.main.id
}

# ==============================================================================
# Storage Account (for data ingestion)
# ==============================================================================

resource "azurerm_storage_account" "main" {
  name                     = "stadx${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"

  tags = var.tags
}

resource "azurerm_storage_container" "raw_data" {
  name                  = "raw-data"
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "sample_data" {
  name                  = "sample-data"
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "private"
}

# ==============================================================================
# Optional: Private Networking
# ==============================================================================

module "networking" {
  source = "./modules/networking"
  count  = var.enable_private_network ? 1 : 0

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  address_space       = var.vnet_address_space
  tags                = var.tags
}

# ==============================================================================
# Azure Data Explorer
# ==============================================================================

module "adx" {
  source = "./modules/adx"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  cluster_name       = var.adx_cluster_name != "" ? var.adx_cluster_name : "adx${random_string.suffix.result}"
  sku_name           = var.adx_sku_name
  capacity           = var.adx_capacity
  database_name      = var.adx_database_name
  hot_cache_period   = var.adx_hot_cache_period
  soft_delete_period = var.adx_soft_delete_period

  allowed_ip_ranges = var.allowed_ip_ranges

  tags = var.tags
}

# ==============================================================================
# Grafana
# ==============================================================================

module "grafana" {
  source = "./modules/grafana"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  suffix              = random_string.suffix.result

  container_name   = "grafana-adx-poc"
  image            = var.grafana_image
  cpu              = var.grafana_cpu
  memory           = var.grafana_memory
  admin_password   = var.grafana_admin_password

  adx_cluster_uri   = module.adx.cluster_uri
  adx_cluster_name  = module.adx.cluster_name
  adx_database_name = var.adx_database_name

  tags = var.tags

  depends_on = [module.adx]
}
