output "id" {
  description = "Resource ID of the virtual network."
  value       = azurerm_virtual_network.this.id
}

output "name" {
  description = "Name of the virtual network."
  value       = azurerm_virtual_network.this.name
}

output "resource_group_name" {
  description = "Name of the virtual network resource group."
  value       = azurerm_virtual_network.this.resource_group_name
}

output "address_space" {
  description = "Address ranges assigned to the virtual network."
  value       = azurerm_virtual_network.this.address_space
}
