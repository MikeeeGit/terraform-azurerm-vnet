# Basic VNet

Creates a resource group and VNet using the original naming interface. No diagnostics, DNS zone or DDoS plan is enabled by default. Authenticate with Azure and set `ARM_SUBSCRIPTION_ID` before an intentional plan/apply. `terraform init -backend=false` and `terraform validate` require no Azure credentials.
