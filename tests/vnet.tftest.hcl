mock_provider "azurerm" {}

variables {
  label               = "example-dev"
  resource_group_name = "example-network-rg"
  location            = "uksouth"
  vnet_ip_range       = ["10.40.0.0/16"]
}

run "original_defaults" {
  command = plan
  assert {
    condition     = output.vnet.name == "example-dev-vnet01" && output.name == output.vnet.name
    error_message = "The original composed name and complete-resource output must be preserved."
  }
  assert {
    condition     = output.vnet.tags.Name == "example-dev-vnet" && output.address_space == toset(["10.40.0.0/16"])
    error_message = "Original tags and address-space output must be retained."
  }
  assert {
    condition     = length(azurerm_monitor_diagnostic_setting.vnet) == 0 && output.diagnostic_setting_id == null && length(azurerm_dns_zone.public) == 0 && length(azurerm_private_dns_zone.private) == 0
    error_message = "The public defaults must not create DNS or send diagnostics to an implicit workspace."
  }
}

run "dns_ddos_and_diagnostics" {
  command = plan
  variables {
    vnet_suffix        = "vnet-01"
    dns_servers        = ["10.40.0.4"]
    tags               = { Environment = "dev", Name = "caller-name" }
    ddos_plan_id       = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/example-security-rg/providers/Microsoft.Network/ddosProtectionPlans/example-plan"
    diag_log_workspace = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/example-monitor-rg/providers/Microsoft.OperationalInsights/workspaces/example-workspace"
    dns = [{
      zone_name     = "example.org"
      a_records     = [{ name = "www", ip = "192.0.2.10" }]
      cname_records = [{ name = "docs", target = "www.example.org" }]
      mx_records    = [{ preference = 10, exchange = "mail.example.org" }]
    }]
    private_dns = [{
      zone_name     = "internal.example.test"
      a_records     = [{ name = "app", ip = "10.40.1.4" }]
      cname_records = [{ name = "api", target = "app.internal.example.test" }]
      mx_records    = [{ preference = 20, exchange = "mail.internal.example.test" }]
    }]
  }
  assert {
    condition     = output.vnet.name == "example-dev-vnet-01" && output.vnet.dns_servers == tolist(["10.40.0.4"]) && output.vnet.tags.Name == "example-dev-vnet" && output.vnet.tags.Environment == "dev" && one(output.vnet.ddos_protection_plan).enable
    error_message = "Custom DNS, DDoS, suffix and original Name tag precedence must reach the VNet."
  }
  assert {
    condition     = one(azurerm_monitor_diagnostic_setting.vnet).log_analytics_workspace_id == var.diag_log_workspace && one(one(azurerm_monitor_diagnostic_setting.vnet).enabled_log).category == "VMProtectionAlerts" && one(one(azurerm_monitor_diagnostic_setting.vnet).enabled_metric).category == "AllMetrics"
    error_message = "Diagnostics must preserve both original categories and use the supplied workspace."
  }
  assert {
    condition     = azurerm_dns_a_record.a_record["example.org.www"].records == toset(["192.0.2.10"]) && azurerm_dns_a_record.a_record["example.org.www"].ttl == 300 && azurerm_dns_cname_record.cname_record["example.org.docs"].record == "www.example.org" && azurerm_dns_mx_record.mx_record["example.org"].name == "@" && tonumber(one(azurerm_dns_mx_record.mx_record["example.org"].record).preference) == 10
    error_message = "Public A, CNAME and apex MX records must preserve the original keys and TTL."
  }
  assert {
    condition     = azurerm_private_dns_a_record.a_record["internal.example.test.app"].records == toset(["10.40.1.4"]) && azurerm_private_dns_cname_record.cname_record["internal.example.test.api"].record == "app.internal.example.test" && azurerm_private_dns_mx_record.mx_record["internal.example.test"].name == "@" && one(azurerm_private_dns_mx_record.mx_record["internal.example.test"].record).preference == 20
    error_message = "Private A, CNAME and apex MX records must remain supported."
  }
  assert {
    condition     = length(azurerm_private_dns_zone_virtual_network_link.private_dns_link) == 1 && !azurerm_private_dns_zone_virtual_network_link.private_dns_link["internal.example.test"].registration_enabled && length(azurerm_private_dns_zone_virtual_network_link.private) == 0
    error_message = "Each private zone needs exactly one non-registering VNet link."
  }
}

run "legacy_zone_selector" {
  command = plan
  variables {
    private_dns   = [{ zone_name = "internal.example.test" }, { zone_name = "other.example.test" }]
    dns_zone_name = "internal.example.test"
  }
  assert {
    condition     = azurerm_private_dns_zone_virtual_network_link.private["private"].private_dns_zone_name == "internal.example.test" && azurerm_private_dns_zone_virtual_network_link.private["private"].name == "example-dev-dns-zone-private" && length(azurerm_private_dns_zone_virtual_network_link.private_dns_link) == 1 && contains(keys(azurerm_private_dns_zone_virtual_network_link.private_dns_link), "other.example.test")
    error_message = "The legacy selector must use the selected zone and avoid duplicate links."
  }
}

run "reject_invalid_cidr" {
  command = plan
  variables { vnet_ip_range = ["not-a-cidr"] }
  expect_failures = [var.vnet_ip_range]
}
run "reject_invalid_name" {
  command = plan
  variables { label = "bad name" }
  expect_failures = [var.label]
}
run "reject_invalid_dns_server" {
  command = plan
  variables { dns_servers = ["10.40.0.4/32"] }
  expect_failures = [var.dns_servers]
}
run "reject_invalid_workspace" {
  command = plan
  variables { diag_log_workspace = "" }
  expect_failures = [var.diag_log_workspace]
}
run "reject_missing_selected_zone" {
  command = plan
  variables { dns_zone_name = "absent.example.test" }
  expect_failures = [var.dns_zone_name]
}
run "reject_duplicate_dns_name" {
  command = plan
  variables {
    dns = [{ zone_name = "example.org", a_records = [{ name = "www", ip = "192.0.2.10" }], cname_records = [{ name = "WWW", target = "other.example.org" }] }]
  }
  expect_failures = [var.dns]
}
run "reject_non_ipv4_a_record" {
  command = plan
  variables {
    private_dns = [{ zone_name = "internal.example.test", a_records = [{ name = "app", ip = "2001:db8::1" }] }]
  }
  expect_failures = [var.private_dns]
}
