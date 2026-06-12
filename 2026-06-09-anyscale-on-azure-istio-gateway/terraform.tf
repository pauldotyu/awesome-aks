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

    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "=1.19.0"
    }

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

locals {
  kubeconfig = yamldecode(base64decode(azapi_resource_action.get_aks_creds.output.kubeconfigs[0].value))
}

provider "kubectl" {
  host                   = local.kubeconfig.clusters[0].cluster.server
  cluster_ca_certificate = base64decode(local.kubeconfig.clusters[0].cluster["certificate-authority-data"])
  client_certificate     = base64decode(local.kubeconfig.users[0].user["client-certificate-data"])
  client_key             = base64decode(local.kubeconfig.users[0].user["client-key-data"])
  token                  = local.kubeconfig.users[0].user.token
  load_config_file       = false
}