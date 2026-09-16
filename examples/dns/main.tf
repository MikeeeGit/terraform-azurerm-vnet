terraform {
  required_version = ">= 1.9.0, < 2.0.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.33.0, < 5.0.0"
    }
  }
}
provider "azurerm" {
  features {}
}
resource "azurerm_resource_group" "example" {
  name     = "example-dev-network-rg"
  location = "uksouth"
}
module "vnet" {
  source              = "../.."
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  label               = "example-dev"
  vnet_ip_range       = ["10.40.0.0/16"]
  tags                = { Environment = "dev", ManagedBy = "Terraform" }
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
    mx_records    = [{ preference = 10, exchange = "mail.internal.example.test" }]
  }]
}
output "vnet" {
  value = module.vnet.vnet
}
