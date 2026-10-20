terraform {
  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.13.0"
    }

    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.10.0"
    }

    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.10.0"
    }

    external = {
      source  = "hashicorp/external"
      version = "~> 2.4.2"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.3.0"
    }

    local = {
      source  = "hashicorp/local"
      version = "~> 2.9.1"
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
    key_vault {
      purge_soft_delete_on_destroy = true
    }
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

provider "helm" {
  kubernetes = {
    host                   = azurerm_kubernetes_cluster.control.kube_config[0].host
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.control.kube_config[0].cluster_ca_certificate)
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "kubelogin"
      args = [
        "get-token",
        "--login",
        "azurecli",
        "--server-id", "6dae42f8-4368-4678-94ff-3960e28e3630",
      ]
    }
  }
}