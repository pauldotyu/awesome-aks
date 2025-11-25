terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.51.0"
    }

    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.7.0"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.1.1"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.7.2"
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

data "azurerm_kubernetes_cluster" "aks" {
  name                = module.avm-res-containerservice-managedcluster.name
  resource_group_name = azurerm_resource_group.example.name
}

provider "helm" {
  kubernetes = {
    host                   = data.azurerm_kubernetes_cluster.aks.kube_config.0.host
    cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.aks.kube_config.0.cluster_ca_certificate)
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "kubelogin" # make sure kubelogin is installed and in your PATH
      args = [
        "get-token",
        "--login",
        "spn",
        "--environment",
        "AzurePublicCloud",
        "--server-id",
        "6dae42f8-4368-4678-94ff-3960e28e3630", # Well-known AKS Server App ID
        "--client-id",
        var.service_principal_client_id,
        "--tenant-id",
        var.service_principal_tenant_id,
        "--client-secret",
        var.service_principal_client_secret
      ]
    }
  }
}