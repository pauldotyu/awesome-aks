terraform {
  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.8.0"
    }

    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.74.0"
    }

    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.10.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.9.0"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}
