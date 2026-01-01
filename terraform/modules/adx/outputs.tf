output "cluster_id" {
  description = "ADX cluster resource ID"
  value       = azurerm_kusto_cluster.main.id
}

output "cluster_name" {
  description = "ADX cluster name"
  value       = azurerm_kusto_cluster.main.name
}

output "cluster_uri" {
  description = "ADX cluster URI for connections"
  value       = azurerm_kusto_cluster.main.uri
}

output "cluster_data_ingestion_uri" {
  description = "ADX cluster data ingestion URI"
  value       = azurerm_kusto_cluster.main.data_ingestion_uri
}

output "cluster_identity_principal_id" {
  description = "Principal ID of the cluster's managed identity"
  value       = azurerm_kusto_cluster.main.identity[0].principal_id
}

output "cluster_identity_tenant_id" {
  description = "Tenant ID of the cluster's managed identity"
  value       = azurerm_kusto_cluster.main.identity[0].tenant_id
}

output "database_id" {
  description = "ADX database resource ID"
  value       = azurerm_kusto_database.main.id
}

output "database_name" {
  description = "ADX database name"
  value       = azurerm_kusto_database.main.name
}
