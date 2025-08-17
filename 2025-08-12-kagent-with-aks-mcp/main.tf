terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.40.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.7.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.38.0"
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


provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.example.kube_config.0.host
  username               = azurerm_kubernetes_cluster.example.kube_config.0.username
  password               = azurerm_kubernetes_cluster.example.kube_config.0.password
  client_certificate     = base64decode(azurerm_kubernetes_cluster.example.kube_config.0.client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.example.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.example.kube_config.0.cluster_ca_certificate)
}

resource "random_integer" "example" {
  min = 1000
  max = 9999
}

resource "azurerm_resource_group" "example" {
  name     = "rg-kagent${random_integer.example.result}"
  location = var.location
}

resource "azurerm_kubernetes_cluster" "example" {
  resource_group_name       = azurerm_resource_group.example.name
  location                  = azurerm_resource_group.example.location
  name                      = "aks-kagent${random_integer.example.result}"
  dns_prefix                = "aks-kagent${random_integer.example.result}"
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  default_node_pool {
    name       = "nodepool1"
    node_count = var.node_pool_count
    vm_size    = var.node_pool_vm_size

    upgrade_settings {
      drain_timeout_in_minutes      = 0
      max_surge                     = "10%"
      node_soak_duration_in_minutes = 0
    }
  }

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_user_assigned_identity" "example" {
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  name                = "aks-mcp"
}

resource "azurerm_role_assignment" "example" {
  principal_id                     = azurerm_user_assigned_identity.example.principal_id
  scope                            = azurerm_resource_group.example.id
  role_definition_name             = "Reader"
  skip_service_principal_aad_check = true
}

resource "azurerm_federated_identity_credential" "example" {
  resource_group_name = azurerm_resource_group.example.name
  parent_id           = azurerm_user_assigned_identity.example.id
  name                = "aks-mcp"
  issuer              = azurerm_kubernetes_cluster.example.oidc_issuer_url
  audience            = ["api://AzureADTokenExchange"]
  subject             = "system:serviceaccount:kagent:aks-mcp"
}

resource "azurerm_cognitive_account" "example" {
  resource_group_name   = azurerm_resource_group.example.name
  location              = azurerm_resource_group.example.location
  name                  = "oai-kagent${random_integer.example.result}"
  custom_subdomain_name = "oai-kagent${random_integer.example.result}"
  kind                  = "OpenAI"
  sku_name              = "S0"
  local_auth_enabled    = true
}

resource "azurerm_cognitive_deployment" "gpt_4o_mini" {
  cognitive_account_id = azurerm_cognitive_account.example.id
  name                 = "gpt-4o-mini"

  model {
    format  = "OpenAI"
    name    = "gpt-4o-mini"
    version = "2024-07-18"
  }

  sku {
    name     = "GlobalStandard"
    capacity = 250
  }
}

resource "kubernetes_namespace_v1" "example" {
  metadata {
    name = "kagent"
  }
}

resource "kubernetes_service_account_v1" "example" {
  metadata {
    name      = "aks-mcp"
    namespace = kubernetes_namespace_v1.example.id
    annotations = {
      "azure.workload.identity/client-id" = azurerm_user_assigned_identity.example.client_id
    }
  }
}

resource "kubernetes_cluster_role_binding_v1" "example" {
  metadata {
    name = "aks-mcp-cluster-admin"
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.example.metadata[0].name
    namespace = kubernetes_namespace_v1.example.id
  }
  role_ref {
    kind      = "ClusterRole"
    name      = "cluster-admin"
    api_group = "rbac.authorization.k8s.io"
  }
}

resource "kubernetes_secret_v1" "example" {
  metadata {
    name      = "azureopenai-gpt-4o-mini"
    namespace = kubernetes_namespace_v1.example.id
  }
  type = "Opaque"
  data = {
    AZUREOPENAI_API_KEY = azurerm_cognitive_account.example.primary_access_key
  }
}

resource "kubernetes_deployment_v1" "example" {
  metadata {
    name      = "aks-mcp"
    namespace = kubernetes_namespace_v1.example.id
    labels = {
      app = "aks-mcp"
    }
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "aks-mcp"
      }
    }
    template {
      metadata {
        labels = {
          app = "aks-mcp"
          "azure.workload.identity/use" : "true"
        }
      }
      spec {
        service_account_name = kubernetes_service_account_v1.example.metadata[0].name
        container {
          image = "ghcr.io/azure/aks-mcp:v0.0.7"
          name  = "aks-mcp"
          args = [
            "--access-level=readwrite",
            "--transport=streamable-http",
            "--host=0.0.0.0",
            "--port=8000",
            "--timeout=600"
          ]
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "example" {
  metadata {
    name      = "aks-mcp"
    namespace = kubernetes_namespace_v1.example.id
  }
  spec {
    port {
      port        = 8000
      target_port = 8000
      protocol    = "TCP"
    }
    selector = {
      app = "aks-mcp"
    }
  }
}