output "vnet_id" {
  description = "Virtual network ID"
  value       = azurerm_virtual_network.main.id
}

output "vnet_name" {
  description = "Virtual network name"
  value       = azurerm_virtual_network.main.name
}

output "adx_subnet_id" {
  description = "ADX subnet ID"
  value       = azurerm_subnet.adx.id
}

output "aci_subnet_id" {
  description = "Container Instance subnet ID"
  value       = azurerm_subnet.aci.id
}

output "bastion_subnet_id" {
  description = "Bastion subnet ID"
  value       = var.enable_bastion ? azurerm_subnet.bastion[0].id : null
}

output "bastion_public_ip" {
  description = "Bastion public IP address"
  value       = var.enable_bastion ? azurerm_public_ip.bastion[0].ip_address : null
}
