output "vnet" {
  description = "Complete virtual network resource, preserving the original module output contract."
  value       = azurerm_virtual_network.main
}

output "id" {
  description = "Virtual network resource ID."
  value       = azurerm_virtual_network.main.id
}

output "name" {
  description = "Composed virtual network name."
  value       = azurerm_virtual_network.main.name
}

output "resource_group_name" {
  description = "Resource group containing the virtual network."
  value       = azurerm_virtual_network.main.resource_group_name
}

output "address_space" {
  description = "Virtual network address ranges."
  value       = azurerm_virtual_network.main.address_space
}

output "public_dns_zone_ids" {
  description = "Created public DNS zone IDs keyed by zone name."
  value       = { for name, zone in azurerm_dns_zone.public : name => zone.id }
}

output "private_dns_zone_ids" {
  description = "Created private DNS zone IDs keyed by zone name."
  value       = { for name, zone in azurerm_private_dns_zone.private : name => zone.id }
}

output "diagnostic_setting_id" {
  description = "VNet diagnostic setting ID, or null when no workspace is supplied."
  value       = one(azurerm_monitor_diagnostic_setting.vnet[*].id)
}
