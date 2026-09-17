# The hub's VNet module creates the zone and its own link. The caller adds
# only the two spoke links, so no DNS zone or link has multiple owners.
resource "azurerm_private_dns_zone_virtual_network_link" "spoke" {
  for_each = local.spokes

  name                  = "${var.name_prefix}-${each.key}-dns-link"
  resource_group_name   = azurerm_resource_group.network["hub"].name
  private_dns_zone_name = local.dns_zone_name
  virtual_network_id    = local.vnets[each.key].id
  registration_enabled  = false

  depends_on = [module.network["hub"]]
}
