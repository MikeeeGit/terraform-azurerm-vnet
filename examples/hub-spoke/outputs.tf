output "virtual_networks" {
  description = "VNet identities and address spaces keyed by hub/spoke role."
  value = { for name, vnet in local.vnets : name => {
    id = vnet.id, name = vnet.name, address_space = vnet.address_space
  } }
}

output "peering_ids" {
  description = "Four directional hub/spoke links; no direct spoke-to-spoke peering."
  value = {
    hub_to_spoke = { for name, peering in azurerm_virtual_network_peering.hub_to_spoke : name => peering.id }
    spoke_to_hub = { for name, peering in azurerm_virtual_network_peering.spoke_to_hub : name => peering.id }
  }
}

output "private_dns_zone_name" {
  description = "Shared private zone linked to all three VNets, initially containing no application records."
  value       = local.dns_zone_name
}

output "subnets" {
  description = "Caller-owned workload subnet settings."
  value       = azurerm_subnet.workload
}

output "network_security_group_ids" {
  description = "Caller-owned NSGs keyed by network role."
  value       = { for name, nsg in azurerm_network_security_group.workload : name => nsg.id }
}

output "nat_gateway_ids" {
  description = "Optional explicit egress gateways keyed by network; empty by default."
  value       = { for name, gateway in azurerm_nat_gateway.egress : name => gateway.id }
}
