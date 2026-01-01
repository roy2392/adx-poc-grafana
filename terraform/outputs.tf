# ==============================================================================
# Resource Group Outputs
# ==============================================================================

output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "resource_group_id" {
  description = "ID of the resource group"
  value       = azurerm_resource_group.main.id
}

# ==============================================================================
# ADX Outputs
# ==============================================================================

output "adx_cluster_name" {
  description = "ADX cluster name"
  value       = module.adx.cluster_name
}

output "adx_cluster_uri" {
  description = "ADX cluster URI for connections"
  value       = module.adx.cluster_uri
}

output "adx_cluster_id" {
  description = "ADX cluster resource ID"
  value       = module.adx.cluster_id
}

output "adx_database_name" {
  description = "ADX database name"
  value       = var.adx_database_name
}

# ==============================================================================
# Grafana Outputs
# ==============================================================================

output "grafana_url" {
  description = "Grafana dashboard URL"
  value       = module.grafana.url
}

output "grafana_fqdn" {
  description = "Grafana fully qualified domain name"
  value       = module.grafana.fqdn
}

output "grafana_admin_user" {
  description = "Grafana admin username"
  value       = "admin"
}

# ==============================================================================
# Storage Outputs
# ==============================================================================

output "storage_account_name" {
  description = "Storage account name for data ingestion"
  value       = azurerm_storage_account.main.name
}

output "storage_account_id" {
  description = "Storage account resource ID"
  value       = azurerm_storage_account.main.id
}

output "storage_primary_blob_endpoint" {
  description = "Storage account primary blob endpoint"
  value       = azurerm_storage_account.main.primary_blob_endpoint
}

# ==============================================================================
# Key Vault Outputs
# ==============================================================================

output "key_vault_name" {
  description = "Key Vault name"
  value       = azurerm_key_vault.main.name
}

output "key_vault_uri" {
  description = "Key Vault URI"
  value       = azurerm_key_vault.main.vault_uri
}

# ==============================================================================
# Connection Information
# ==============================================================================

output "connection_info" {
  description = "Quick reference for connecting to resources"
  value = <<-EOT

    ╔══════════════════════════════════════════════════════════════════╗
    ║                    ADX POC - Connection Info                     ║
    ╠══════════════════════════════════════════════════════════════════╣
    ║                                                                  ║
    ║  Grafana Dashboard:                                              ║
    ║  URL: ${module.grafana.url}
    ║  Username: admin                                                 ║
    ║  Password: (stored in Key Vault: ${azurerm_key_vault.main.name})
    ║                                                                  ║
    ║  Azure Data Explorer:                                            ║
    ║  Cluster: ${module.adx.cluster_uri}
    ║  Database: ${var.adx_database_name}
    ║                                                                  ║
    ║  Storage Account: ${azurerm_storage_account.main.name}
    ║                                                                  ║
    ╚══════════════════════════════════════════════════════════════════╝

  EOT
}
