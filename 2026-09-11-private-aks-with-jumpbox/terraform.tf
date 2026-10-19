terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.5.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.9.1"
    }

    time = {
      source  = "hashicorp/time"
      version = "~> 0.14.2"
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
