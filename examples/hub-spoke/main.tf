locals {
  networks = {
    hub = {
      address_space = "10.60.0.0/16"
      subnet_prefix = "10.60.1.0/24"
      subnet_name   = "shared-services"
    }
    spoke-app = {
      address_space = "10.61.0.0/16"
      subnet_prefix = "10.61.1.0/24"
      subnet_name   = "application"
    }
    spoke-data = {
      address_space = "10.62.0.0/16"
      subnet_prefix = "10.62.1.0/24"
      subnet_name   = "data"
    }
  }
  spokes        = { for name, network in local.networks : name => network if name != "hub" }
  dns_zone_name = "internal.example.test"
  tags          = merge(var.tags, { Environment = "example", ManagedBy = "Terraform" })
}

resource "azurerm_resource_group" "network" {
  for_each = local.networks
  name     = "${var.name_prefix}-${each.key}-rg"
  location = var.location
  tags     = local.tags
}

module "network" {
  source   = "../.."
  for_each = local.networks

  resource_group_name = azurerm_resource_group.network[each.key].name
  location            = azurerm_resource_group.network[each.key].location
  label               = "${var.name_prefix}-${each.key}"
  vnet_suffix         = "vnet-01"
  vnet_ip_range       = [each.value.address_space]
  tags                = local.tags
  private_dns         = each.key == "hub" ? [{ zone_name = local.dns_zone_name }] : []
}

locals {
  vnets = { for name, network in module.network : name => network.vnet }
}

# This leaf module owns VNet/DNS only; the example caller owns subnet policy.
resource "azurerm_subnet" "workload" {
  for_each = local.networks

  name                            = "${var.name_prefix}-${each.key}-${each.value.subnet_name}"
  resource_group_name             = azurerm_resource_group.network[each.key].name
  virtual_network_name            = local.vnets[each.key].name
  address_prefixes                = [each.value.subnet_prefix]
  default_outbound_access_enabled = false
}
