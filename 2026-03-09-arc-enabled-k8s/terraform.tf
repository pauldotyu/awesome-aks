terraform {
  required_providers {
    azapi = {
      source  = "azure/azapi"
      version = "~> 2.8.0"
    }

    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.8.0"
    }

    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.63.0"
    }

    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = "~> 2.3.7"
    }

    http = {
      source  = "hashicorp/http"
      version = "~> 3.5.0"
    }

    local = {
      source  = "hashicorp/local"
      version = "~> 2.7.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.8.1"
    }

    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.2.1"
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

provider "azapi" {}