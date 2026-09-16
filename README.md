# terraform-azurerm-vnet

Azure VNet and DNS module, adapted from `AZ-TF-MOD-vnet`. It keeps the original naming, public/private DNS record composition and whole-resource output so existing Terraform roots can continue to use the design.

The module creates one VNet, optional public and private DNS zones with A/CNAME/MX records, one VNet link per private zone, and optional VNet diagnostics. It associates an existing DDoS Protection Plan when supplied. Resource groups, workspaces, DDoS plans, subnets, peerings and private endpoints belong to the caller or other modules.

## Usage

```hcl
module "vnet" {
  source = "git::https://github.com/MikeeeGit/terraform-azurerm-vnet.git?ref=v0.2.0"

  resource_group_name = azurerm_resource_group.network.name
  location            = azurerm_resource_group.network.location
  label               = "example-dev"
  vnet_ip_range       = ["10.40.0.0/16"]
  tags                = { Environment = "dev", ManagedBy = "Terraform" }

  private_dns = [{
    zone_name     = "internal.example.test"
    a_records     = [{ name = "app", ip = "10.40.1.4" }]
    cname_records = [{ name = "api", target = "app.internal.example.test" }]
    mx_records    = []
  }]
}

output "vnet_id" {
  value = module.vnet.vnet.id
}
```

Requires Terraform `>= 1.9.0, < 2.0.0` and AzureRM `>= 4.33.0, < 5.0.0`. The minimum provider version supports `enabled_metric`, preserving metrics without the deprecated `metric` block. Configure the AzureRM provider and authentication in the calling root. This reusable module has no backend or provider configuration.

## Inputs

| Input | Type | Default / meaning |
| --- | --- | --- |
| `resource_group_name` | string | Required existing RG |
| `location` | string | Required Azure region |
| `label` | string | Required naming prefix |
| `vnet_ip_range` | list(string) | Required nonempty CIDR list |
| `vnet_suffix` | string | `vnet01`; name is `<label>-<suffix>` |
| `tags` | map(string) | `{}`; generated `Name` tag takes precedence |
| `dns_servers` | list(string) | `[]` for Azure DNS; otherwise IP addresses |
| `ddos_plan_id` | string | `""`; existing plan ID enables association |
| `diag_log_workspace` | string or null | `null`; explicit workspace ID enables diagnostics |
| `dns` | list(object) | `[]`; public DNS configuration below |
| `private_dns` | list(object) | `[]`; private DNS configuration below |
| `dns_zone_name` | string | `""`; optional legacy link selector |

`dns` and `private_dns` share this schema. Each record collection is optional and defaults to `[]`, while the original explicit empty collections remain accepted:

```hcl
dns = [{
  zone_name     = "example.org"
  a_records     = [{ name = "www", ip = "192.0.2.10" }]
  cname_records = [{ name = "docs", target = "www.example.org" }]
  mx_records    = [{ preference = 10, exchange = "mail.example.org" }]
}]
```

A records contain one IPv4 address per name. CNAME records contain one target. MX records form one apex (`@`) set per zone. All record TTLs remain 300 seconds. Zone names are unique within each collection; A/CNAME names are unique within each zone. DNS resolution and registrar delegation are outside this module.

Private zones are created in the supplied RG and linked to the VNet with registration disabled. Normally the link is `<zone>-link`. If `dns_zone_name` exactly matches a configured private zone, that zone instead uses the original `<label>-dns-zone-private` link. The fixed selector uses the selected zone name and avoids creating a duplicate link. It is not a way to reference an existing external zone; callers can create their own links for external zones.

Diagnostics send both `VMProtectionAlerts` and `AllMetrics` to the explicitly supplied workspace. The workspace ID's null/non-null status must be known at plan time. No workspace ID, tenant, subscription or estate name is supplied by default. For a newly created workspace whose ID is unknown at plan time, supply a deterministically constructed workspace ID or provision the workspace in a separate foundation first.

The generated VNet `Name` tag is `<label>-vnet`, even when the suffix differs. Public/private zones use `<label>-public-dns` and `<label>-private-dns`. This retains the original tag contract.

## Outputs

`vnet` is the complete `azurerm_virtual_network.main` resource, preserving consumers such as `module.vnet.vnet.id` and `.name`. Convenience outputs are `id`, `name`, `resource_group_name`, `address_space`, `public_dns_zone_ids`, `private_dns_zone_ids` and `diagnostic_setting_id` (null when disabled). DNS ID maps use zone names as keys.

## Examples and verification

- [Basic](examples/basic): resource group and VNet.
- [DNS](examples/dns): public/private A, CNAME and MX records with reserved example data.
- [Migration notes](docs/MIGRATION.md): source changes, diagnostic state address and compatibility.

```sh
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
terraform test
```

The tests use mocked AzureRM resources and need no Azure credentials. They verify original defaults, DNS records/link selection, diagnostics, DDoS and rejected inputs. They do not establish live Azure connectivity, permissions, DNS resolution or deployment success. Shared GitHub Actions and Azure Pipelines validate this module and its examples without cloud credentials. Real deployments need an intentional plan and a caller-owned backend/provider configuration.

Licensed under [Apache-2.0](LICENSE). See [contributing](CONTRIBUTING.md) and [security reporting](SECURITY.md).
