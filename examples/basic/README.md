# Basic virtual network

Creates a resource group and one virtual network with Azure-provided DNS. All names and address ranges are synthetic. Review the address space and region before use.

From this directory, run `terraform init` and `terraform validate` to check the example. Planning or deploying also requires an Azure identity with appropriate permissions and `ARM_SUBSCRIPTION_ID` set to your subscription. Use workload identity federation in CI. Keep backend configuration and credentials outside this example.

The module has no inline subnets. Create subnets separately, using `module.vnet.name` and your resource group name. No paid DDoS plan or diagnostic workspace is created by this example.
