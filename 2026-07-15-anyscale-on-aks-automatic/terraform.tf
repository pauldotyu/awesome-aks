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

# provider "helm" {
#   kubernetes = {
#     host                   = azurerm_kubernetes_cluster.example.kube_config.0.host
#     username               = azurerm_kubernetes_cluster.example.kube_config.0.username
#     password               = azurerm_kubernetes_cluster.example.kube_config.0.password
#     client_certificate     = base64decode(azurerm_kubernetes_cluster.example.kube_config.0.client_certificate)
#     client_key             = base64decode(azurerm_kubernetes_cluster.example.kube_config.0.client_key)
#     cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.example.kube_config.0.cluster_ca_certificate)
#   }
# }

# provider "kubectl" {
#   host                   = azurerm_kubernetes_cluster.example.kube_config.0.host
#   username               = azurerm_kubernetes_cluster.example.kube_config.0.username
#   password               = azurerm_kubernetes_cluster.example.kube_config.0.password
#   client_certificate     = base64decode(azurerm_kubernetes_cluster.example.kube_config.0.client_certificate)
#   client_key             = base64decode(azurerm_kubernetes_cluster.example.kube_config.0.client_key)
#   cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.example.kube_config.0.cluster_ca_certificate)
#   load_config_file       = false
# }