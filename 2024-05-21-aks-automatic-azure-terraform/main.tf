terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.103.1"
    }

    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.49.1"
    }

    azapi = {
      source  = "Azure/azapi"
      version = "=1.13.1"
    }

    random = {
      source  = "hashicorp/random"
      version = "=3.6.1"
    }
  }
}

provider "azapi" {
}

provider "azurerm" {
  features {
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
  length    = 2
  separator = ""
  keepers = {
    location = var.location
  }
}

data "azurerm_client_config" "current" {}

data "azuread_user" "current" {
  object_id = data.azurerm_client_config.current.object_id
}

resource "azurerm_resource_group" "example" {
  location = var.location
  name     = "rg-${local.random_name}"
}