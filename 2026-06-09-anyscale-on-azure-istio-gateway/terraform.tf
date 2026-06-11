terraform {
  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.10.0"
    }

    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.8.0"
    }

    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.76.0"
    }

    # helm = {
    #   source  = "hashicorp/helm"
    #   version = "=3.1.1"
    # }

    # kubectl = {
    #   source  = "gavinbunney/kubectl"
    #   version = "=1.19.0"
    # }

    local = {
      source  = "hashicorp/local"
      version = "~> 2.9.0"
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
