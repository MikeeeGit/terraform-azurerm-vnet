terraform {
  required_version = ">= 1.9, < 2.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.0, < 5.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "example" {
  name     = "rg-network-example"
  location = "uksouth"
}

module "vnet" {
  source = "../.."

  name                = "vnet-network-example"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  address_space       = ["10.80.0.0/16"]
  tags = {
    environment = "example"
    managed_by  = "terraform"
  }
}

output "vnet_id" {
  description = "Resource ID of the example virtual network."
  value       = module.vnet.id
}
