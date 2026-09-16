# Migration to v0.2.0

## From AZ-TF-MOD-vnet

Keep the existing module block name and input values while changing its source. Original input names, resource labels (`main`, `public`, `private`, record labels), DNS record keys, naming and `vnet` output are retained. No live state is copied into this repository.

Review these deliberate changes before applying:

1. Set `diag_log_workspace` explicitly to your existing workspace ID if retaining diagnostics. The estate-specific default has been removed; omission now disables the setting. The module includes a `moved` block from `azurerm_monitor_diagnostic_setting.vnet` to `azurerm_monitor_diagnostic_setting.vnet[0]`. Terraform can preserve the existing setting at the same module path when an explicit workspace is provided. Omission with an existing setting plans its removal.
2. Upgrade to Terraform >=1.9 and AzureRM >=4.33,<5. The provider's `enabled_metric` syntax retains `AllMetrics`; `VMProtectionAlerts` remains enabled. Use your normal provider upgrade process and inspect the full plan.
3. `dns_zone_name` must be empty or match a configured private zone. The previous implementation looked up the literal key `private`, and also attempted a second link to the same zone. The repaired branch creates one selected link. If an existing state has a normal `<zone>-link`, enabling the selector changes its resource address/name; retain an empty selector to preserve the default link naming.
4. Invalid CIDRs, invalid composed VNet names, empty workspace IDs, duplicate DNS keys, invalid A addresses and invalid MX preferences now fail early. These checks do not validate address overlap, ownership of public domains, Azure permissions or all Azure service-specific constraints.
5. MX record name `@` is explicit, matching the original provider default. Original TTLs and record shapes are unchanged. Optional record collections may now be omitted.

The VNet remains `<label>-<vnet_suffix>` and the leaf suffix remains `vnet01`. Do not change labels/suffixes as part of an otherwise mechanical source migration: that can replace or rename resources. Run a saved plan against a secured copy of your real configuration before applying. Do not add production tfvars, plans, state or secrets to a public fork.

## From the provisional v0.1.0 public module

v0.2.0 restores the reviewed original architecture and is a breaking API change from the initial narrowed public scaffold. Replace `name` with `label`/`vnet_suffix`, `address_space` with `vnet_ip_range`, `ddos_protection_plan_id` with `ddos_plan_id` and `log_analytics_workspace_id` with `diag_log_workspace`. The restored resource address is `azurerm_virtual_network.main`, not `.this`. Diagnostics also use the original `vnet` label.

If you applied v0.1.0, review resource addresses and use deliberate moved blocks/imports in your own migration. No broad automatic mapping is included because labels, names and DNS ownership may differ. Avoid mixing two module versions that manage the same VNet DNS configuration. The compatibility target is the reviewed original design, not an unreviewed in-place upgrade from the provisional scaffold.
