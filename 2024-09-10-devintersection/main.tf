terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=4.1.0"
    }

    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.53.1"
    }

    azapi = {
      source  = "Azure/azapi"
      version = "=1.15.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "=3.6.2"
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
    cognitive_account {
      purge_soft_delete_on_destroy = true
    }
  }
}

resource "random_integer" "example" {
  min = 10
  max = 99
}

data "azurerm_client_config" "current" {}

data "azuread_user" "current" {
  object_id = data.azurerm_client_config.current.object_id
}

resource "azurerm_resource_group" "example" {
  location = var.location
  name     = "rg-${local.random_name}"

  tags = {
    event = "devintersection"
  }
}