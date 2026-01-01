# ==============================================================================
# Data Sources
# ==============================================================================

data "azurerm_client_config" "current" {}

# ==============================================================================
# Storage for Grafana Data Persistence
# ==============================================================================

resource "azurerm_storage_account" "grafana" {
  name                     = "stgrafana${var.suffix}"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"

  tags = var.tags
}

resource "azurerm_storage_share" "grafana_data" {
  name                 = "grafana-data"
  storage_account_name = azurerm_storage_account.grafana.name
  quota                = 5
}

# ==============================================================================
# Container Instance for Grafana
# ==============================================================================

resource "azurerm_container_group" "grafana" {
  name                = var.container_name
  location            = var.location
  resource_group_name = var.resource_group_name
  os_type             = "Linux"
  ip_address_type     = "Public"
  dns_name_label      = "${var.container_name}-${var.suffix}"

  container {
    name   = "grafana"
    image  = var.image
    cpu    = var.cpu
    memory = var.memory

    ports {
      port     = 3000
      protocol = "TCP"
    }

    environment_variables = {
      # Grafana configuration
      GF_SERVER_ROOT_URL     = "http://${var.container_name}-${var.suffix}.${var.location}.azurecontainer.io:3000"
      GF_SECURITY_ADMIN_USER = "admin"

      # Install ADX plugin
      GF_INSTALL_PLUGINS = "grafana-azure-data-explorer-datasource"

      # Disable anonymous access
      GF_AUTH_ANONYMOUS_ENABLED = "false"

      # ADX connection info (for reference in UI)
      ADX_CLUSTER_URL   = var.adx_cluster_uri
      ADX_DATABASE_NAME = var.adx_database_name
      ADX_TENANT_ID     = data.azurerm_client_config.current.tenant_id
    }

    secure_environment_variables = {
      GF_SECURITY_ADMIN_PASSWORD = var.admin_password
    }

    volume {
      name                 = "grafana-data"
      mount_path           = "/var/lib/grafana"
      storage_account_name = azurerm_storage_account.grafana.name
      storage_account_key  = azurerm_storage_account.grafana.primary_access_key
      share_name           = azurerm_storage_share.grafana_data.name
    }

    # Liveness probe
    liveness_probe {
      http_get {
        path   = "/api/health"
        port   = 3000
        scheme = "Http"
      }
      initial_delay_seconds = 60
      period_seconds        = 30
      failure_threshold     = 3
    }
  }

  tags = var.tags
}
