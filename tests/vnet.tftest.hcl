mock_provider "azurerm" {}

variables {
  name                = "vnet-test"
  resource_group_name = "rg-test"
  location            = "uksouth"
  address_space       = ["10.80.0.0/16"]
}

run "minimal_network" {
  command = plan

  assert {
    condition     = azurerm_virtual_network.this.name == "vnet-test" && output.name == "vnet-test"
    error_message = "The VNet name must be used exactly as supplied and exposed as an output."
  }

  assert {
    condition     = output.resource_group_name == "rg-test" && toset(output.address_space) == toset(["10.80.0.0/16"])
    error_message = "The resource group and address space outputs must describe the VNet."
  }

  assert {
    condition     = length(azurerm_virtual_network.this.dns_servers) == 0 && length(azurerm_virtual_network.this.ddos_protection_plan) == 0
    error_message = "The default network must use Azure DNS and omit a paid DDoS plan association."
  }

  assert {
    condition     = length(azurerm_monitor_diagnostic_setting.this) == 0
    error_message = "No diagnostics may be created without an explicitly supplied workspace."
  }
}

run "optional_network_settings" {
  command = plan

  variables {
    dns_servers                = ["10.80.0.4", "10.80.0.5"]
    tags                       = { environment = "test", Name = "caller-tag" }
    ddos_protection_plan_id    = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-security/providers/Microsoft.Network/ddosProtectionPlans/ddos-example"
    log_analytics_workspace_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-monitoring/providers/Microsoft.OperationalInsights/workspaces/law-example"
  }

  assert {
    condition     = azurerm_virtual_network.this.dns_servers == tolist(["10.80.0.4", "10.80.0.5"])
    error_message = "Custom DNS servers must be forwarded to the virtual network."
  }

  assert {
    condition     = azurerm_virtual_network.this.tags["Name"] == "caller-tag" && length(azurerm_virtual_network.this.tags) == 2
    error_message = "Caller tags must be preserved without injecting organization-specific tags."
  }

  assert {
    condition     = one(azurerm_virtual_network.this.ddos_protection_plan).enable && one(azurerm_virtual_network.this.ddos_protection_plan).id == var.ddos_protection_plan_id
    error_message = "A supplied DDoS plan must be enabled on the network."
  }

  assert {
    condition     = length(azurerm_monitor_diagnostic_setting.this) == 1 && azurerm_monitor_diagnostic_setting.this[0].log_analytics_workspace_id == var.log_analytics_workspace_id
    error_message = "Diagnostics must use only the workspace explicitly supplied by the caller."
  }

  assert {
    condition     = one(azurerm_monitor_diagnostic_setting.this[0].enabled_log).category == "VMProtectionAlerts"
    error_message = "Diagnostics must enable the supported virtual network protection alert category."
  }
}

run "dual_stack_address_space" {
  command = plan

  variables {
    address_space = ["10.80.0.0/16", "fd00:1234:5678::/48"]
  }

  assert {
    condition     = length(output.address_space) == 2
    error_message = "Valid IPv4 and IPv6 ranges must be accepted."
  }
}

run "reject_invalid_cidr" {
  command = plan
  variables {
    address_space = ["10.80.0.0/99"]
  }
  expect_failures = [var.address_space]
}

run "reject_empty_address_space" {
  command = plan
  variables {
    address_space = []
  }
  expect_failures = [var.address_space]
}

run "reject_duplicate_address_space" {
  command = plan
  variables {
    address_space = ["10.80.0.0/16", "10.80.0.0/16"]
  }
  expect_failures = [var.address_space]
}

run "reject_invalid_name" {
  command = plan
  variables {
    name = "invalid name!"
  }
  expect_failures = [var.name]
}

run "reject_name_with_trailing_hyphen" {
  command = plan
  variables {
    name = "vnet-test-"
  }
  expect_failures = [var.name]
}

run "reject_invalid_dns_server" {
  command = plan
  variables {
    dns_servers = ["10.80.0.4/24"]
  }
  expect_failures = [var.dns_servers]
}

run "reject_empty_ddos_id" {
  command = plan
  variables {
    ddos_protection_plan_id = ""
  }
  expect_failures = [var.ddos_protection_plan_id]
}

run "reject_invalid_workspace_id" {
  command = plan
  variables {
    log_analytics_workspace_id = "law-example"
  }
  expect_failures = [var.log_analytics_workspace_id]
}
