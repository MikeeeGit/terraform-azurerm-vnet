# terraform-azurerm-vnet

A focused Terraform module for one Azure virtual network, custom DNS servers, an optional existing DDoS Protection Plan, and optional protection-alert diagnostics. It is a public rewrite of `AZ-TF-MOD-vnet` with explicit inputs and no organization-specific resource IDs, naming policy, or provider configuration.

This module is an independent community project, not an Azure Verified Module. It is intended as a small, understandable building block for a wider network foundation.

## Usage

Configure the AzureRM provider and authentication in the calling root module. The following example assumes this repository is checked out beside that root:

```hcl
provider "azurerm" {
  features {}
}

module "vnet" {
  source = "../terraform-azurerm-vnet"

  name                = "vnet-example"
  resource_group_name = "rg-example"
  location            = "uksouth"
  address_space       = ["10.80.0.0/16"]
  tags = {
    environment = "example"
    managed_by  = "terraform"
  }
}
```

The resource group must already exist. [The complete basic example](examples/basic) creates its own synthetic resource group. After publication, consumers can use either Git host and pin the module source to a reviewed commit or release tag. No remote source URL is declared until the public repositories exist.

## Requirements

| Dependency | Version |
| --- | --- |
| Terraform | `>= 1.9, < 2.0` |
| `hashicorp/azurerm` | `>= 4.0, < 5.0` |

Provider and backend configuration belong to the caller. For an actual deployment, AzureRM 4 requires a subscription ID, for example through `ARM_SUBSCRIPTION_ID`. Use workload identity federation for CI authentication. Credentials and state must never be committed to this repository. The checked-in dependency locks record the versions used for this repository's checks; consumers resolve providers through their own root lock file.

## Inputs

| Name | Type | Default | Purpose |
| --- | --- | --- | --- |
| `name` | `string` | required | Complete VNet name; 2-64 characters using Azure's naming rules. |
| `resource_group_name` | `string` | required | Existing resource group name. |
| `location` | `string` | required | Azure region. |
| `address_space` | `list(string)` | required | One or more distinct IPv4 or IPv6 CIDR ranges. |
| `dns_servers` | `list(string)` | `[]` | Custom DNS server IPs; empty uses Azure-provided DNS. |
| `tags` | `map(string)` | `{}` | Caller-owned tags, passed through without overrides. |
| `ddos_protection_plan_id` | `string` | `null` | Existing DDoS Protection Plan resource ID. |
| `log_analytics_workspace_id` | `string` | `null` | Existing Log Analytics workspace resource ID for diagnostics. |

Optional resource IDs accept `null`, not empty strings. The null/non-null value of `log_analytics_workspace_id` must be known at plan time because it controls whether a diagnostic setting exists. Supply an existing workspace ID, rather than a newly created workspace's computed ID in the same plan.

CIDR validation checks syntax and duplicate entries. Callers must still design non-overlapping address spaces and comply with Azure's dual-stack requirements. Setting custom DNS servers does not deploy a resolver or configure forwarding rules.

## Outputs

| Name | Purpose |
| --- | --- |
| `id` | Virtual network resource ID. |
| `name` | Virtual network name. |
| `resource_group_name` | Virtual network resource group name. |
| `address_space` | Virtual network address ranges. |

## Design and scope

- Subnets are managed separately, so the module never mixes inline subnet blocks with standalone subnet resources.
- Private DNS zones, links and records belong in the calling network composition. Public DNS zones and records have their own lifecycle and are outside this VNet module.
- The module owns the VNet's DNS server list. Do not also use `azurerm_virtual_network_dns_servers` against the same network.
- The module attaches an existing DDoS plan only when requested. It does not create a paid plan or claim to provide complete DDoS protection on its own.
- Diagnostics are absent by default. A supplied workspace enables the `VMProtectionAlerts` resource-log category. This does not configure VNet flow logs, Network Watcher, subscription activity logs, metric export or alert rules. Metrics can be configured separately where required; this keeps compatibility with the AzureRM 4.0 diagnostic schema without using the deprecated `metric` block.
- Production network security also needs subnet policies, routing, controlled egress, access controls, and monitoring appropriate to the workloads. These are intentionally composed outside this resource module.

## Local checks

```shell
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
terraform test
terraform -chdir=examples/basic init -backend=false
terraform -chdir=examples/basic validate
```

The native Terraform tests use a mocked provider and `command = plan`. They require no Azure credentials and do not create cloud resources. They cover default behavior, optional DNS/DDoS/diagnostics settings, tag preservation, dual-stack address syntax, and invalid inputs. Initialization downloads provider binaries. A passing mock test demonstrates configuration behavior, not a live Azure deployment or service capability test.

## Migration from AZ-TF-MOD-vnet

This is a breaking interface change, not an in-place source replacement:

| Legacy input or output | New interface |
| --- | --- |
| `label` and `vnet_suffix` | Supply their previous combined value as `name` to retain the Azure resource name. |
| `vnet_ip_range` | `address_space` |
| `ddos_plan_id = ""` | `ddos_protection_plan_id = null` |
| `diag_log_workspace` with an implicit default | Explicit `log_analytics_workspace_id`, or `null` to omit diagnostics. |
| `dns`, `dns_zone_name`, `private_dns` | Move DNS resources into separately managed modules or the root composition. |
| `vnet` whole-resource output | Explicit `id`, `name`, `resource_group_name`, and `address_space` outputs. |

For an existing deployment, back up state and inventory every resource before changing the module source. Preserve DNS resources with explicit state moves/imports into their new owners; removing their old configuration without doing this would schedule deletion. No migration is performed automatically by this repository.

The VNet address changes from `azurerm_virtual_network.main` to `azurerm_virtual_network.this`. For a root that uses `module "vnet"` before and after, a caller-owned move can preserve that state address:

```hcl
moved {
  from = module.vnet.azurerm_virtual_network.main
  to   = module.vnet.azurerm_virtual_network.this
}
```

Adapt the addresses to your real module hierarchy. The old diagnostic resource was `azurerm_monitor_diagnostic_setting.vnet`; the new optional resource is `azurerm_monitor_diagnostic_setting.this[0]`, and its setting name changes from `<vnet-name>-log` to `<vnet-name>-diagnostics`. Review the resulting replacement and the removal of metric export separately. Tags no longer inject a `Name` value, so supply that tag explicitly if it must be retained. Review a real plan for unintended replacement or destruction before applying any migration.

## References

- [AzureRM virtual network resource](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network)
- [Azure resource naming rules](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/resource-name-rules#microsoftnetwork)
- [Azure Virtual Network monitoring data reference](https://learn.microsoft.com/en-us/azure/virtual-network/monitor-virtual-network-reference)
- [AzureRM 4.0 diagnostic setting schema](https://github.com/hashicorp/terraform-provider-azurerm/blob/v4.0.0/website/docs/r/monitor_diagnostic_setting.html.markdown)
