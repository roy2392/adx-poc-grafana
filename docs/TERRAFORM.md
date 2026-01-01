# Terraform Implementation Guide

## Overview

This document details the Terraform infrastructure-as-code implementation for the ADX POC.

## Module Structure

```
terraform/
├── main.tf                 # Root module - orchestrates all resources
├── variables.tf            # Input variables
├── outputs.tf              # Output values
├── providers.tf            # Provider configuration
├── versions.tf             # Version constraints
├── terraform.tfvars.example
└── modules/
    ├── adx/
    │   ├── main.tf         # ADX cluster & database
    │   ├── variables.tf
    │   ├── outputs.tf
    │   └── scripts/        # KQL setup scripts
    ├── grafana/
    │   ├── main.tf         # ACI deployment
    │   ├── variables.tf
    │   ├── outputs.tf
    │   └── provisioning/   # Dashboard JSON files
    └── networking/
        ├── main.tf         # VNet, subnets, NSGs
        ├── variables.tf
        └── outputs.tf
```

---

## Root Module

### providers.tf

```hcl
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.45"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }

  # Uncomment for remote state
  # backend "azurerm" {
  #   resource_group_name  = "rg-terraform-state"
  #   storage_account_name = "tfstateadxpoc"
  #   container_name       = "tfstate"
  #   key                  = "adx-poc.tfstate"
  # }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = true
    }
  }
}

provider "azuread" {}
```

### variables.tf

```hcl
# General
variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "rg-adx-poc"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "eastus"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "ADX-POC"
    ManagedBy   = "Terraform"
  }
}

# ADX Configuration
variable "adx_cluster_name" {
  description = "Name of the ADX cluster (must be globally unique)"
  type        = string
  default     = ""  # Auto-generated if empty
}

variable "adx_sku_name" {
  description = "ADX cluster SKU"
  type        = string
  default     = "Dev(No SLA)_Standard_D11_v2"

  validation {
    condition = contains([
      "Dev(No SLA)_Standard_D11_v2",
      "Dev(No SLA)_Standard_E2a_v4",
      "Standard_D11_v2",
      "Standard_D12_v2",
      "Standard_D13_v2",
      "Standard_D14_v2"
    ], var.adx_sku_name)
    error_message = "Invalid ADX SKU name."
  }
}

variable "adx_capacity" {
  description = "Number of instances in the ADX cluster"
  type        = number
  default     = 1
}

variable "adx_database_name" {
  description = "Name of the ADX database"
  type        = string
  default     = "analytics"
}

# Grafana Configuration
variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
}

variable "grafana_image" {
  description = "Grafana container image"
  type        = string
  default     = "grafana/grafana-oss:10.2.0"
}

# Networking
variable "enable_private_network" {
  description = "Deploy resources with private networking"
  type        = bool
  default     = false
}

variable "allowed_ip_ranges" {
  description = "IP ranges allowed to access ADX (CIDR format)"
  type        = list(string)
  default     = []
}
```

### main.tf

```hcl
# Random suffix for globally unique names
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# Key Vault for secrets
resource "azurerm_key_vault" "main" {
  name                = "kv-adx-poc-${random_string.suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  purge_protection_enabled = false  # Set true for production

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = ["Get", "List", "Set", "Delete", "Purge"]
  }

  tags = var.tags
}

# Storage Account for data ingestion
resource "azurerm_storage_account" "main" {
  name                     = "stadxpoc${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = var.tags
}

resource "azurerm_storage_container" "raw_data" {
  name                  = "raw-data"
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "private"
}

# Optional: Private Networking
module "networking" {
  source = "./modules/networking"
  count  = var.enable_private_network ? 1 : 0

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = var.tags
}

# ADX Cluster & Database
module "adx" {
  source = "./modules/adx"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  cluster_name  = var.adx_cluster_name != "" ? var.adx_cluster_name : "adxpoc${random_string.suffix.result}"
  sku_name      = var.adx_sku_name
  capacity      = var.adx_capacity
  database_name = var.adx_database_name

  allowed_ip_ranges = var.allowed_ip_ranges

  tags = var.tags
}

# Grafana
module "grafana" {
  source = "./modules/grafana"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  container_name    = "grafana-adx-poc"
  image             = var.grafana_image
  admin_password    = var.grafana_admin_password

  adx_cluster_uri   = module.adx.cluster_uri
  adx_database_name = var.adx_database_name

  key_vault_id = azurerm_key_vault.main.id

  tags = var.tags

  depends_on = [module.adx]
}

# Data sources
data "azurerm_client_config" "current" {}
```

### outputs.tf

```hcl
output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "adx_cluster_uri" {
  description = "ADX cluster URI"
  value       = module.adx.cluster_uri
}

output "adx_cluster_name" {
  description = "ADX cluster name"
  value       = module.adx.cluster_name
}

output "adx_database_name" {
  description = "ADX database name"
  value       = var.adx_database_name
}

output "grafana_url" {
  description = "Grafana dashboard URL"
  value       = module.grafana.url
}

output "grafana_admin_user" {
  description = "Grafana admin username"
  value       = "admin"
}

output "storage_account_name" {
  description = "Storage account for data ingestion"
  value       = azurerm_storage_account.main.name
}

output "key_vault_name" {
  description = "Key Vault name"
  value       = azurerm_key_vault.main.name
}
```

---

## ADX Module

### modules/adx/main.tf

```hcl
resource "azurerm_kusto_cluster" "main" {
  name                = var.cluster_name
  location            = var.location
  resource_group_name = var.resource_group_name

  sku {
    name     = var.sku_name
    capacity = var.capacity
  }

  identity {
    type = "SystemAssigned"
  }

  streaming_ingestion_enabled = true
  purge_enabled               = true

  tags = var.tags
}

resource "azurerm_kusto_database" "main" {
  name                = var.database_name
  resource_group_name = var.resource_group_name
  location            = var.location
  cluster_name        = azurerm_kusto_cluster.main.name

  hot_cache_period   = "P7D"    # 7 days hot cache
  soft_delete_period = "P31D"   # 31 days retention
}

# Execute setup script after database creation
resource "null_resource" "setup_schema" {
  depends_on = [azurerm_kusto_database.main]

  provisioner "local-exec" {
    command = <<-EOT
      az kusto script create \
        --cluster-name ${azurerm_kusto_cluster.main.name} \
        --database-name ${azurerm_kusto_database.main.name} \
        --resource-group ${var.resource_group_name} \
        --script-content "$(cat ${path.module}/scripts/setup-schema.kql)" \
        --name setup-schema
    EOT
  }
}
```

### modules/adx/scripts/setup-schema.kql

```kql
// Create IoT Sensors table
.create table IoTSensors (
    Timestamp: datetime,
    DeviceId: string,
    Temperature: real,
    Humidity: real,
    Pressure: real,
    Location: string
)

// Create Application Logs table
.create table AppLogs (
    Timestamp: datetime,
    Level: string,
    Service: string,
    Message: string,
    TraceId: string
)

// Create Metrics table
.create table Metrics (
    Timestamp: datetime,
    MetricName: string,
    Value: real,
    Dimensions: dynamic
)

// Enable streaming ingestion
.alter table IoTSensors policy streamingingestion enable
.alter table AppLogs policy streamingingestion enable
.alter table Metrics policy streamingingestion enable

// Create ingestion mappings
.create table IoTSensors ingestion json mapping 'IoTSensorsMapping'
'[{"column":"Timestamp","path":"$.timestamp"},{"column":"DeviceId","path":"$.device_id"},{"column":"Temperature","path":"$.temperature"},{"column":"Humidity","path":"$.humidity"},{"column":"Pressure","path":"$.pressure"},{"column":"Location","path":"$.location"}]'

// Create useful functions
.create-or-alter function AvgTempByDevice() {
    IoTSensors
    | where Timestamp > ago(1h)
    | summarize AvgTemp = avg(Temperature), AvgHumidity = avg(Humidity) by DeviceId
    | order by AvgTemp desc
}

.create-or-alter function ErrorRateByService() {
    AppLogs
    | where Timestamp > ago(1h)
    | summarize
        TotalLogs = count(),
        Errors = countif(Level == "Error"),
        Warnings = countif(Level == "Warning")
        by Service
    | extend ErrorRate = round(100.0 * Errors / TotalLogs, 2)
    | order by ErrorRate desc
}

.create-or-alter function MetricsSummary(metricName: string, timeRange: timespan) {
    Metrics
    | where Timestamp > ago(timeRange) and MetricName == metricName
    | summarize
        Avg = avg(Value),
        Min = min(Value),
        Max = max(Value),
        P95 = percentile(Value, 95)
        by bin(Timestamp, 1m)
}
```

---

## Grafana Module

### modules/grafana/main.tf

```hcl
# Service Principal for ADX access
resource "azuread_application" "grafana" {
  display_name = "sp-grafana-adx-${var.container_name}"
}

resource "azuread_service_principal" "grafana" {
  client_id = azuread_application.grafana.client_id
}

resource "azuread_service_principal_password" "grafana" {
  service_principal_id = azuread_service_principal.grafana.id
  end_date_relative    = "8760h" # 1 year
}

# Grant ADX database viewer access
resource "azurerm_kusto_database_principal_assignment" "grafana" {
  name                = "grafana-viewer"
  resource_group_name = var.resource_group_name
  cluster_name        = local.adx_cluster_name
  database_name       = var.adx_database_name

  tenant_id      = data.azurerm_client_config.current.tenant_id
  principal_id   = azuread_service_principal.grafana.object_id
  principal_type = "App"
  role           = "Viewer"
}

# Storage for Grafana data persistence
resource "azurerm_storage_account" "grafana" {
  name                     = "stgrafana${random_string.suffix.result}"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags                     = var.tags
}

resource "azurerm_storage_share" "grafana" {
  name                 = "grafana-data"
  storage_account_name = azurerm_storage_account.grafana.name
  quota                = 5
}

# Container Instance for Grafana
resource "azurerm_container_group" "grafana" {
  name                = var.container_name
  location            = var.location
  resource_group_name = var.resource_group_name
  os_type             = "Linux"
  ip_address_type     = "Public"
  dns_name_label      = var.container_name

  container {
    name   = "grafana"
    image  = var.image
    cpu    = 1
    memory = 1.5

    ports {
      port     = 3000
      protocol = "TCP"
    }

    environment_variables = {
      GF_INSTALL_PLUGINS                    = "grafana-azure-data-explorer-datasource"
      GF_SECURITY_ADMIN_USER                = "admin"
      GF_SERVER_ROOT_URL                    = "http://${var.container_name}.${var.location}.azurecontainer.io:3000"
      GF_AUTH_ANONYMOUS_ENABLED             = "false"
      GF_DASHBOARDS_DEFAULT_HOME_DASHBOARD_PATH = "/var/lib/grafana/dashboards/adx-overview.json"

      # ADX Data Source Config
      ADX_CLUSTER_URL = var.adx_cluster_uri
      ADX_TENANT_ID   = data.azurerm_client_config.current.tenant_id
      ADX_CLIENT_ID   = azuread_application.grafana.client_id
    }

    secure_environment_variables = {
      GF_SECURITY_ADMIN_PASSWORD = var.admin_password
      ADX_CLIENT_SECRET          = azuread_service_principal_password.grafana.value
    }

    volume {
      name                 = "grafana-data"
      mount_path           = "/var/lib/grafana"
      storage_account_name = azurerm_storage_account.grafana.name
      storage_account_key  = azurerm_storage_account.grafana.primary_access_key
      share_name           = azurerm_storage_share.grafana.name
    }
  }

  tags = var.tags
}

# Data sources
data "azurerm_client_config" "current" {}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

locals {
  adx_cluster_name = regex("https://([^.]+)\\.", var.adx_cluster_uri)[0]
}
```

### modules/grafana/outputs.tf

```hcl
output "url" {
  description = "Grafana URL"
  value       = "http://${azurerm_container_group.grafana.fqdn}:3000"
}

output "fqdn" {
  description = "Grafana FQDN"
  value       = azurerm_container_group.grafana.fqdn
}

output "service_principal_id" {
  description = "Service principal client ID for ADX access"
  value       = azuread_application.grafana.client_id
}
```

---

## Networking Module (Optional)

### modules/networking/main.tf

```hcl
resource "azurerm_virtual_network" "main" {
  name                = "vnet-adx-poc"
  address_space       = ["10.0.0.0/16"]
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_subnet" "adx" {
  name                 = "snet-adx"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "aci" {
  name                 = "snet-aci"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]

  delegation {
    name = "aci-delegation"
    service_delegation {
      name    = "Microsoft.ContainerInstance/containerGroups"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

resource "azurerm_network_security_group" "aci" {
  name                = "nsg-aci"
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "allow-grafana"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3000"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = var.tags
}
```

---

## State Management

### Remote Backend (Recommended)

```hcl
# Create storage for state (run once)
# az storage account create -n tfstateadxpoc -g rg-terraform-state -l eastus --sku Standard_LRS
# az storage container create -n tfstate --account-name tfstateadxpoc

terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "tfstateadxpoc"
    container_name       = "tfstate"
    key                  = "adx-poc.tfstate"
  }
}
```

---

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Terraform Deploy

on:
  push:
    branches: [main]
    paths: ['terraform/**']
  pull_request:
    branches: [main]
    paths: ['terraform/**']

env:
  ARM_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
  ARM_CLIENT_SECRET: ${{ secrets.AZURE_CLIENT_SECRET }}
  ARM_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
  ARM_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}

jobs:
  terraform:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: terraform

    steps:
      - uses: actions/checkout@v4

      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.6.0

      - name: Terraform Init
        run: terraform init

      - name: Terraform Validate
        run: terraform validate

      - name: Terraform Plan
        run: terraform plan -out=tfplan
        if: github.event_name == 'pull_request'

      - name: Terraform Apply
        run: terraform apply -auto-approve tfplan
        if: github.ref == 'refs/heads/main' && github.event_name == 'push'
```
