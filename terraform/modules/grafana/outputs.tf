output "url" {
  description = "Grafana URL"
  value       = "http://${azurerm_container_group.grafana.fqdn}:3000"
}

output "fqdn" {
  description = "Grafana fully qualified domain name"
  value       = azurerm_container_group.grafana.fqdn
}

output "ip_address" {
  description = "Grafana public IP address"
  value       = azurerm_container_group.grafana.ip_address
}

output "container_group_id" {
  description = "Container group resource ID"
  value       = azurerm_container_group.grafana.id
}

output "storage_account_name" {
  description = "Storage account name for Grafana data"
  value       = azurerm_storage_account.grafana.name
}

output "tenant_id" {
  description = "Azure tenant ID for ADX connection"
  value       = data.azurerm_client_config.current.tenant_id
}
