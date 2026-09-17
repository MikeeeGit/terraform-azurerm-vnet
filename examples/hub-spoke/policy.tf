locals {
  nsg_rules = {
    "hub" = [
      {
        "name"                       = "allow-app-https",
        "priority"                   = 100,
        "direction"                  = "Inbound",
        "access"                     = "Allow",
        "protocol"                   = "Tcp",
        "source_port_range"          = "*",
        "destination_port_range"     = "443",
        "source_address_prefix"      = "10.61.1.0/24",
        "destination_address_prefix" = "10.60.1.0/24"
      },
      {
        "name"                       = "allow-data-https",
        "priority"                   = 110,
        "direction"                  = "Inbound",
        "access"                     = "Allow",
        "protocol"                   = "Tcp",
        "source_port_range"          = "*",
        "destination_port_range"     = "443",
        "source_address_prefix"      = "10.62.1.0/24",
        "destination_address_prefix" = "10.60.1.0/24"
      },
      {
        "name"                       = "deny-other-vnet-inbound",
        "priority"                   = 4000,
        "direction"                  = "Inbound",
        "access"                     = "Deny",
        "protocol"                   = "*",
        "source_port_range"          = "*",
        "destination_port_range"     = "*",
        "source_address_prefix"      = "VirtualNetwork",
        "destination_address_prefix" = "*"
      },
      {
        "name"                       = "allow-monitoring-https",
        "priority"                   = 200,
        "direction"                  = "Outbound",
        "access"                     = "Allow",
        "protocol"                   = "Tcp",
        "source_port_range"          = "*",
        "destination_port_range"     = "443",
        "source_address_prefix"      = "*",
        "destination_address_prefix" = "AzureMonitor"
      },
      {
        "name"                       = "deny-other-internet-outbound",
        "priority"                   = 4000,
        "direction"                  = "Outbound",
        "access"                     = "Deny",
        "protocol"                   = "*",
        "source_port_range"          = "*",
        "destination_port_range"     = "*",
        "source_address_prefix"      = "*",
        "destination_address_prefix" = "Internet"
      }
    ],
    "spoke-app" = [
      {
        "name"                       = "allow-hub-https",
        "priority"                   = 100,
        "direction"                  = "Inbound",
        "access"                     = "Allow",
        "protocol"                   = "Tcp",
        "source_port_range"          = "*",
        "destination_port_range"     = "443",
        "source_address_prefix"      = "10.60.1.0/24",
        "destination_address_prefix" = "10.61.1.0/24"
      },
      {
        "name"                       = "deny-other-vnet-inbound",
        "priority"                   = 4000,
        "direction"                  = "Inbound",
        "access"                     = "Deny",
        "protocol"                   = "*",
        "source_port_range"          = "*",
        "destination_port_range"     = "*",
        "source_address_prefix"      = "VirtualNetwork",
        "destination_address_prefix" = "*"
      },
      {
        "name"                       = "allow-monitoring-https",
        "priority"                   = 200,
        "direction"                  = "Outbound",
        "access"                     = "Allow",
        "protocol"                   = "Tcp",
        "source_port_range"          = "*",
        "destination_port_range"     = "443",
        "source_address_prefix"      = "*",
        "destination_address_prefix" = "AzureMonitor"
      },
      {
        "name"                       = "deny-other-internet-outbound",
        "priority"                   = 4000,
        "direction"                  = "Outbound",
        "access"                     = "Deny",
        "protocol"                   = "*",
        "source_port_range"          = "*",
        "destination_port_range"     = "*",
        "source_address_prefix"      = "*",
        "destination_address_prefix" = "Internet"
      }
    ],
    "spoke-data" = [
      {
        "name"                       = "allow-hub-https",
        "priority"                   = 100,
        "direction"                  = "Inbound",
        "access"                     = "Allow",
        "protocol"                   = "Tcp",
        "source_port_range"          = "*",
        "destination_port_range"     = "443",
        "source_address_prefix"      = "10.60.1.0/24",
        "destination_address_prefix" = "10.62.1.0/24"
      },
      {
        "name"                       = "deny-other-vnet-inbound",
        "priority"                   = 4000,
        "direction"                  = "Inbound",
        "access"                     = "Deny",
        "protocol"                   = "*",
        "source_port_range"          = "*",
        "destination_port_range"     = "*",
        "source_address_prefix"      = "VirtualNetwork",
        "destination_address_prefix" = "*"
      },
      {
        "name"                       = "allow-monitoring-https",
        "priority"                   = 200,
        "direction"                  = "Outbound",
        "access"                     = "Allow",
        "protocol"                   = "Tcp",
        "source_port_range"          = "*",
        "destination_port_range"     = "443",
        "source_address_prefix"      = "*",
        "destination_address_prefix" = "AzureMonitor"
      },
      {
        "name"                       = "deny-other-internet-outbound",
        "priority"                   = 4000,
        "direction"                  = "Outbound",
        "access"                     = "Deny",
        "protocol"                   = "*",
        "source_port_range"          = "*",
        "destination_port_range"     = "*",
        "source_address_prefix"      = "*",
        "destination_address_prefix" = "Internet"
      }
    ]
  }
}

resource "azurerm_network_security_group" "workload" {
  for_each = local.networks

  name                = "${var.name_prefix}-${each.key}-nsg"
  resource_group_name = azurerm_resource_group.network[each.key].name
  location            = azurerm_resource_group.network[each.key].location
  tags                = local.tags

  dynamic "security_rule" {
    for_each = local.nsg_rules[each.key]
    content {
      name                       = security_rule.value.name
      priority                   = security_rule.value.priority
      direction                  = security_rule.value.direction
      access                     = security_rule.value.access
      protocol                   = security_rule.value.protocol
      source_port_range          = security_rule.value.source_port_range
      destination_port_range     = security_rule.value.destination_port_range
      source_address_prefix      = security_rule.value.source_address_prefix
      destination_address_prefix = security_rule.value.destination_address_prefix
    }
  }
}

resource "azurerm_subnet_network_security_group_association" "workload" {
  for_each = local.networks

  subnet_id                 = azurerm_subnet.workload[each.key].id
  network_security_group_id = azurerm_network_security_group.workload[each.key].id
}

resource "azurerm_route_table" "workload" {
  for_each = local.networks

  name                = "${var.name_prefix}-${each.key}-rt"
  resource_group_name = azurerm_resource_group.network[each.key].name
  location            = azurerm_resource_group.network[each.key].location
  tags                = local.tags

  route {
    name           = "monitoring-direct"
    address_prefix = "AzureMonitor"
    next_hop_type  = "Internet"
  }
}

resource "azurerm_subnet_route_table_association" "workload" {
  for_each = local.networks

  subnet_id      = azurerm_subnet.workload[each.key].id
  route_table_id = azurerm_route_table.workload[each.key].id
}
