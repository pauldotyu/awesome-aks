terraform {
  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.9.0"
    }

    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.0.1"
    }

    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.11.0"
    }


    helm = {
      source  = "hashicorp/helm"
      version = "=3.2.0"
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

provider "helm" {
  kubernetes = {
    host                   = local.kubeconfig.clusters[0].cluster.server
    cluster_ca_certificate = base64decode(local.kubeconfig.clusters[0].cluster["certificate-authority-data"])

    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "kubelogin"
      args = [
        "get-token",
        "--login",
        "azurecli",
        "--server-id",
        "6dae42f8-4368-4678-94ff-3960e28e3630"
      ]
    }
  }
}