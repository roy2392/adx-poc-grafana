# ==============================================================================
# General Configuration
# ==============================================================================

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
    Project   = "ADX-POC"
    ManagedBy = "Terraform"
  }
}

# ==============================================================================
# ADX Configuration
# ==============================================================================

variable "adx_cluster_name" {
  description = "Name of the ADX cluster (must be globally unique). Leave empty for auto-generated name."
  type        = string
  default     = ""
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
      "Standard_D14_v2",
      "Standard_E2a_v4",
      "Standard_E4a_v4"
    ], var.adx_sku_name)
    error_message = "Invalid ADX SKU name. Choose from Dev or Standard tiers."
  }
}

variable "adx_capacity" {
  description = "Number of instances in the ADX cluster"
  type        = number
  default     = 1

  validation {
    condition     = var.adx_capacity >= 1 && var.adx_capacity <= 10
    error_message = "ADX capacity must be between 1 and 10."
  }
}

variable "adx_database_name" {
  description = "Name of the ADX database"
  type        = string
  default     = "analytics"
}

variable "adx_hot_cache_period" {
  description = "Hot cache period for ADX database (ISO 8601 duration)"
  type        = string
  default     = "P7D"
}

variable "adx_soft_delete_period" {
  description = "Soft delete period for ADX database (ISO 8601 duration)"
  type        = string
  default     = "P31D"
}

# ==============================================================================
# Grafana Configuration
# ==============================================================================

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

variable "grafana_cpu" {
  description = "CPU cores for Grafana container"
  type        = number
  default     = 1
}

variable "grafana_memory" {
  description = "Memory in GB for Grafana container"
  type        = number
  default     = 1.5
}

# ==============================================================================
# Networking Configuration
# ==============================================================================

variable "enable_private_network" {
  description = "Deploy resources with private networking (VNet integration)"
  type        = bool
  default     = false
}

variable "allowed_ip_ranges" {
  description = "IP ranges allowed to access ADX (CIDR format). Empty allows Azure services."
  type        = list(string)
  default     = []
}

variable "vnet_address_space" {
  description = "Address space for VNet (when private networking enabled)"
  type        = string
  default     = "10.0.0.0/16"
}
