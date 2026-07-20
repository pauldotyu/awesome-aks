terraform {
  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.10.0"
    }

    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.9.0"
    }

    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.81.0"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "=3.1.1"
    }

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

locals {
  kubeconfig = yamldecode(base64decode(azapi_resource_action.get_aks_creds.output.kubeconfigs[0].value))
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

# provider "kubectl" {
#   host                   = azurerm_kubernetes_cluster.example.kube_config.0.host
#   username               = azurerm_kubernetes_cluster.example.kube_config.0.username
#   password               = azurerm_kubernetes_cluster.example.kube_config.0.password
#   client_certificate     = base64decode(azurerm_kubernetes_cluster.example.kube_config.0.client_certificate)
#   client_key             = base64decode(azurerm_kubernetes_cluster.example.kube_config.0.client_key)
#   cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.example.kube_config.0.cluster_ca_certificate)
#   load_config_file       = false
# }