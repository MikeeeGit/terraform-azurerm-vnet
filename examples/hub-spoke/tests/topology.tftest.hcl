mock_provider "azurerm" {
  mock_resource "azurerm_subnet" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/example-hub-rg/providers/Microsoft.Network/virtualNetworks/example-hub-vnet-01/subnets/mock-subnet" }
  }
  mock_resource "azurerm_network_security_group" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/example-hub-rg/providers/Microsoft.Network/networkSecurityGroups/mock-nsg" }
  }
  mock_resource "azurerm_route_table" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/example-hub-rg/providers/Microsoft.Network/routeTables/mock-rt" }
  }
  mock_resource "azurerm_virtual_network" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/example-hub-rg/providers/Microsoft.Network/virtualNetworks/mock-vnet" }
  }

  mock_resource "azurerm_nat_gateway" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/example-hub-rg/providers/Microsoft.Network/natGateways/mock-nat" }
  }

  mock_resource "azurerm_public_ip" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/example-hub-rg/providers/Microsoft.Network/publicIPAddresses/mock-pip" }
  }

}

run "hub_two_spokes_and_policy" {
  command = apply
  override_resource {
    target = module.network["hub"].azurerm_virtual_network.main
    values = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/example-hub-rg/providers/Microsoft.Network/virtualNetworks/example-hub-vnet-01" }
  }
  override_resource {
    target = module.network["spoke-app"].azurerm_virtual_network.main
    values = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/example-spoke-app-rg/providers/Microsoft.Network/virtualNetworks/example-spoke-app-vnet-01" }
  }
  override_resource {
    target = module.network["spoke-data"].azurerm_virtual_network.main
    values = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/example-spoke-data-rg/providers/Microsoft.Network/virtualNetworks/example-spoke-data-vnet-01" }
  }
  assert {
    condition     = length(azurerm_nat_gateway.egress) == 0 && length(azurerm_public_ip.egress) == 0
    error_message = "Default topology must not silently provision public egress or billable NAT gateways."
  }
  assert {
    condition     = length(output.virtual_networks) == 3 && length(azurerm_resource_group.network) == 3 && contains(output.virtual_networks["hub"].address_space, "10.60.0.0/16") && contains(output.virtual_networks["spoke-app"].address_space, "10.61.0.0/16") && contains(output.virtual_networks["spoke-data"].address_space, "10.62.0.0/16")
    error_message = "The example must create one hub and two distinct spokes in separate resource groups with nonoverlapping address spaces."
  }
  assert {
    condition     = length(azurerm_virtual_network_peering.hub_to_spoke) == 2 && length(azurerm_virtual_network_peering.spoke_to_hub) == 2 && alltrue([for name in ["spoke-app", "spoke-data"] : azurerm_virtual_network_peering.hub_to_spoke[name].remote_virtual_network_id == output.virtual_networks[name].id && azurerm_virtual_network_peering.spoke_to_hub[name].remote_virtual_network_id == output.virtual_networks["hub"].id && azurerm_virtual_network_peering.spoke_to_hub[name].virtual_network_name == output.virtual_networks[name].name])
    error_message = "Each spoke must have both peering directions wired to its own VNet and the hub, never to the other spoke."
  }
  assert {
    condition     = alltrue([for peering in concat(values(azurerm_virtual_network_peering.hub_to_spoke), values(azurerm_virtual_network_peering.spoke_to_hub)) : peering.allow_virtual_network_access && !peering.allow_forwarded_traffic && !peering.allow_gateway_transit && !peering.use_remote_gateways])
    error_message = "Ordinary peering must not claim forwarding, gateway transit or implicit hub inspection."
  }
  assert {
    condition     = length(module.network["hub"].private_dns_zone_ids) == 1 && length(module.network["spoke-app"].private_dns_zone_ids) == 0 && length(module.network["spoke-data"].private_dns_zone_ids) == 0 && length(azurerm_private_dns_zone_virtual_network_link.spoke) == 2 && alltrue([for name, link in azurerm_private_dns_zone_virtual_network_link.spoke : link.virtual_network_id == output.virtual_networks[name].id && link.private_dns_zone_name == "internal.example.test" && !link.registration_enabled])
    error_message = "Only the hub module owns the zone/hub link; the caller must add exactly the two spoke links."
  }
  assert {
    condition     = length(output.subnets) == 3 && alltrue([for name, subnet in output.subnets : !subnet.default_outbound_access_enabled && subnet.virtual_network_name == output.virtual_networks[name].name]) && length(azurerm_subnet_network_security_group_association.workload) == 3 && length(azurerm_subnet_route_table_association.workload) == 3
    error_message = "Every caller-owned subnet needs explicit private outbound behavior and both policy associations."
  }
  assert {
    condition     = alltrue([for nsg in azurerm_network_security_group.workload : anytrue([for rule in nsg.security_rule : rule.name == "deny-other-vnet-inbound" && rule.access == "Deny" && rule.priority == 4000]) && anytrue([for rule in nsg.security_rule : rule.name == "allow-monitoring-https" && rule.destination_address_prefix == "AzureMonitor" && rule.destination_port_range == "443"])]) && length([for rule in azurerm_network_security_group.workload["hub"].security_rule : rule if rule.direction == "Inbound" && rule.access == "Allow"]) == 2
    error_message = "NSGs must allow each intended hub/spoke HTTPS source and override broad default VNet ingress with an explicit deny."
  }
  assert {
    condition     = alltrue([for table in azurerm_route_table.workload : length(table.route) == 1 && one(table.route).address_prefix == "AzureMonitor" && one(table.route).next_hop_type == "Internet"])
    error_message = "Example routes must target AzureMonitor directly; no default blackhole or nonexistent firewall route is permitted."
  }
}

run "custom_resource_prefix" {
  command = plan
  variables { name_prefix = "portfolio" }
  assert {
    condition     = output.virtual_networks["hub"].name == "portfolio-hub-vnet-01" && output.virtual_networks["spoke-app"].name == "portfolio-spoke-app-vnet-01" && azurerm_resource_group.network["spoke-data"].name == "portfolio-spoke-data-rg"
    error_message = "The example prefix must propagate consistently without changing logical map keys."
  }
}

run "reject_invalid_prefix" {
  command = plan
  variables { name_prefix = "UPPER" }
  expect_failures = [var.name_prefix]
}

run "optional_explicit_nat_egress" {
  command = apply
  variables { enable_nat_gateway = true }
  assert {
    condition     = length(azurerm_nat_gateway.egress) == 3 && length(azurerm_public_ip.egress) == 3 && length(azurerm_nat_gateway_public_ip_association.egress) == 3 && length(azurerm_subnet_nat_gateway_association.egress) == 3 && alltrue([for name, link in azurerm_subnet_nat_gateway_association.egress : link.nat_gateway_id == azurerm_nat_gateway.egress[name].id && link.subnet_id == local.subnet_ids[name]])
    error_message = "Opt-in outbound connectivity must attach a gateway to each VNet's own subnet; a peered hub gateway cannot supply spoke egress."
  }
}
