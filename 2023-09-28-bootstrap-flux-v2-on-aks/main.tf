terraform {
  required_providers {
    # azapi = {
    #   source  = "Azure/azapi"
    #   version = "=1.9.0"
    # }

    azuread = {
      source  = "hashicorp/azuread"
      version = "= 2.43.0"
    }

    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.74.0"
    }

    external = {
      source  = "hashicorp/external"
      version = "=2.3.1"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "=2.23.0"
    }

    local = {
      source  = "hashicorp/local"
      version = "=2.4.0"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }

    cognitive_account {
      purge_soft_delete_on_destroy = true
    }

    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }
}

provider "kubernetes" {
  config_path = local_file.kubeconfig.filename
}

data "azurerm_subscription" "current" {}
data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "example" {
  name     = "rg-${local.name}"
  location = local.location
}
