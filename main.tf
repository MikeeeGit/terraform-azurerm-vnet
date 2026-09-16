resource "azurerm_virtual_network" "main" {
  name                = "${var.label}-${var.vnet_suffix}"
  resource_group_name = var.resource_group_name
  address_space       = var.vnet_ip_range
  location            = var.location
  dns_servers         = var.dns_servers
  dynamic "ddos_protection_plan" {
    for_each = var.ddos_plan_id != "" ? [true] : []
    content {
      id     = var.ddos_plan_id
      enable = true
    }
  }
  tags = merge(
    var.tags,
    {
      "Name" = "${var.label}-vnet"
    }
  )
}

# Create Public DNS Zones and Records
resource "azurerm_dns_zone" "public" {
  for_each            = { for zone in var.dns : zone.zone_name => zone }
  name                = each.value.zone_name
  resource_group_name = var.resource_group_name
  tags                = merge(var.tags, { "Name" = "${var.label}-public-dns" })
}

resource "azurerm_dns_a_record" "a_record" {
  for_each = {
    for record in flatten([
      for zone in var.dns : [
        for a in zone.a_records : {
          key       = "${zone.zone_name}.${a.name}"
          zone_name = zone.zone_name
          name      = a.name
          ip        = a.ip
        }
      ]
    ]) : record.key => record
  }

  zone_name           = each.value.zone_name
  resource_group_name = var.resource_group_name
  name                = each.value.name
  ttl                 = 300
  records             = [each.value.ip]

  depends_on = [azurerm_dns_zone.public]
}




resource "azurerm_dns_cname_record" "cname_record" {
  for_each = {
    for record in flatten([
      for zone in var.dns : [
        for cname in zone.cname_records : {
          key       = "${zone.zone_name}.${cname.name}"
          zone_name = zone.zone_name
          name      = cname.name
          target    = cname.target
        }
      ]
    ]) : record.key => record
  }

  zone_name           = each.value.zone_name
  resource_group_name = var.resource_group_name
  name                = each.value.name
  ttl                 = 300
  record              = each.value.target

  depends_on = [azurerm_dns_zone.public]
}



resource "azurerm_dns_mx_record" "mx_record" {
  for_each = {
    for zone in var.dns : zone.zone_name => zone
    if length(zone.mx_records) > 0
  }

  name                = "@"
  zone_name           = each.key
  resource_group_name = var.resource_group_name
  ttl                 = 300

  dynamic "record" {
    for_each = each.value.mx_records
    content {
      preference = record.value.preference
      exchange   = record.value.exchange
    }
  }

  depends_on = [azurerm_dns_zone.public]
}


# Create Private DNS Zones
resource "azurerm_private_dns_zone" "private" {
  for_each            = { for zone in var.private_dns : zone.zone_name => zone }
  name                = each.value.zone_name
  resource_group_name = var.resource_group_name
  tags                = merge(var.tags, { "Name" = "${var.label}-private-dns" })
}

# Link Private DNS Zone to the Current VNet
resource "azurerm_private_dns_zone_virtual_network_link" "private_dns_link" {
  for_each              = { for name, zone in azurerm_private_dns_zone.private : name => zone if name != var.dns_zone_name }
  name                  = "${each.key}-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = each.value.name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false
}

# Create Private DNS A Records
resource "azurerm_private_dns_a_record" "a_record" {
  for_each = {
    for record in flatten([
      for zone in var.private_dns : [
        for a in zone.a_records : {
          key       = "${zone.zone_name}.${a.name}"
          zone_name = zone.zone_name
          name      = a.name
          ip        = a.ip
        }
      ]
    ]) : record.key => record
  }

  zone_name           = each.value.zone_name
  resource_group_name = var.resource_group_name
  name                = each.value.name
  ttl                 = 300
  records             = [each.value.ip]

  depends_on = [azurerm_private_dns_zone.private]
}

# Create Private DNS CNAME Records
resource "azurerm_private_dns_cname_record" "cname_record" {
  for_each = {
    for record in flatten([
      for zone in var.private_dns : [
        for cname in zone.cname_records : {
          key       = "${zone.zone_name}.${cname.name}"
          zone_name = zone.zone_name
          name      = cname.name
          target    = cname.target
        }
      ]
    ]) : record.key => record
  }

  zone_name           = each.value.zone_name
  resource_group_name = var.resource_group_name
  name                = each.value.name
  ttl                 = 300
  record              = each.value.target

  depends_on = [azurerm_private_dns_zone.private]
}

# Create Private DNS MX Records
resource "azurerm_private_dns_mx_record" "mx_record" {
  for_each = {
    for zone in var.private_dns : zone.zone_name => zone
    if length(zone.mx_records) > 0
  }

  name                = "@"
  zone_name           = each.key
  resource_group_name = var.resource_group_name
  ttl                 = 300

  dynamic "record" {
    for_each = each.value.mx_records
    content {
      preference = record.value.preference
      exchange   = record.value.exchange
    }
  }

  depends_on = [azurerm_private_dns_zone.private]
}


resource "azurerm_private_dns_zone_virtual_network_link" "private" {
  for_each              = var.dns_zone_name != "" ? { private = var.dns_zone_name } : {}
  name                  = "${var.label}-dns-zone-private"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.private[each.value].name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false
}
#########################################################################
# VNet Diagnostics
#########################################################################
resource "azurerm_monitor_diagnostic_setting" "vnet" {
  count = var.diag_log_workspace == null ? 0 : 1

  name                       = "${azurerm_virtual_network.main.name}-log"
  target_resource_id         = azurerm_virtual_network.main.id
  log_analytics_workspace_id = var.diag_log_workspace
  enabled_log {
    category = "VMProtectionAlerts"
  }
  enabled_metric {
    category = "AllMetrics"
  }
}
