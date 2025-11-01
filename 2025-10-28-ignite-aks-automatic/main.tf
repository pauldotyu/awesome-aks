terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.50.0"
    }

    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.7.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.7.2"
    }
  }
}

provider "azurerm" {
  features {
    cognitive_account {
      purge_soft_delete_on_destroy = true
    }
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

resource "random_integer" "example" {
  min = 10
  max = 99
}

resource "random_pet" "example" {
  length    = 1
  separator = ""
  keepers = {
    location = var.location
  }
}

data "azurerm_client_config" "current" {}

// https://learn.microsoft.com/azure/templates/microsoft.resources/resourcegroups?pivots=deployment-language-terraform
resource "azapi_resource" "rg" {
  type     = "Microsoft.Resources/resourceGroups@2025-04-01"
  name     = "rg-${local.random_name}"
  location = var.location
  tags     = var.tags
  body = {
    properties = {}
  }
}
