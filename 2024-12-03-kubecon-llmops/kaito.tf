# Create managed identity that the gpu-provisioner will use to interact with Azure
resource "azurerm_user_assigned_identity" "kaito" {
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  name                = "kaitoprovisioner"
}

# Grant the managed identity the Contributor role to create new AKS nodes
resource "azurerm_role_assignment" "kaito_aks_contributor" {
  principal_id                     = azurerm_user_assigned_identity.kaito.principal_id
  scope                            = azurerm_kubernetes_cluster.example.id
  role_definition_name             = "Contributor"
  skip_service_principal_aad_check = true
}

# Create a federated identity credential for the managed identity to be used by the gpu-provisioner via workload identity
resource "azurerm_federated_identity_credential" "kaito" {
  resource_group_name = azurerm_resource_group.example.name
  parent_id           = azurerm_user_assigned_identity.kaito.id
  name                = "kaitoprovisioner"
  issuer              = azurerm_kubernetes_cluster.example.oidc_issuer_url
  audience            = ["api://AzureADTokenExchange"]
  subject             = "system:serviceaccount:gpu-provisioner:gpu-provisioner"
}

# Install the gpu-provisioner chart
resource "helm_release" "gpu_provisioner" {
  name             = "gpu-provisioner"
  chart            = "https://raw.githubusercontent.com/Azure/kaito/refs/heads/gh-pages/charts/kaito/gpu-provisioner-${var.kaito_gpu_provisioner_version}.tgz"
  namespace        = "gpu-provisioner"
  create_namespace = true

  values = [
    templatefile("${path.module}/gpu-provisioner-values.tmpl",
      {
        AZURE_TENANT_ID          = data.azurerm_client_config.current.tenant_id
        AZURE_SUBSCRIPTION_ID    = data.azurerm_client_config.current.subscription_id
        RG_NAME                  = azurerm_resource_group.example.name
        LOCATION                 = azurerm_resource_group.example.location
        AKS_NAME                 = azurerm_kubernetes_cluster.example.name
        AKS_NRG_NAME             = azurerm_kubernetes_cluster.example.node_resource_group
        KAITO_IDENTITY_CLIENT_ID = azurerm_user_assigned_identity.kaito.client_id
      }
    )
  ]
}

# Install the kaito-workspace chart
resource "helm_release" "kaito_workspace" {
  name             = "kaito-workspace"
  chart            = "https://raw.githubusercontent.com/Azure/kaito/refs/heads/gh-pages/charts/kaito/workspace-${var.kaito_workspace_version}.tgz"
  namespace        = "kaito-workspace"
  create_namespace = true
}

resource "kubernetes_namespace" "example" {
  metadata {
    name = "pets"
  }
}

# Create a secret to store the Azure Container Registry credentials for the workspace to refer to when pushing and pulling images from the registry
resource "kubernetes_secret" "registry" {
  metadata {
    name      = "myregistrysecret"
    namespace = kubernetes_namespace.example.metadata[0].name
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        "${azurerm_container_registry.example.login_server}" = {
          "username" = azurerm_container_registry_token.example.name
          "password" = azurerm_container_registry_token_password.example.password1[0].value
          "auth"     = base64encode("${azurerm_container_registry_token.example.name}:${azurerm_container_registry_token_password.example.password1[0].value}")
        }
      }
    })
  }

  depends_on = [azurerm_container_registry_token_password.example]
}

# Create a secret to store azure event hub shared access key
resource "kubernetes_secret" "eventhub" {
  metadata {
    name      = "myeventhubsecret"
    namespace = kubernetes_namespace.example.metadata[0].name
  }

  type = "Opaque"

  data = {
    "sharedAccessKeyName" = "RootManageSharedAccessKey"
    "sharedAccessKey"     = azurerm_eventhub_namespace.example.default_primary_key
  }
}

resource "azurerm_storage_account" "example" {
  name                     = "sto${local.random_name}"
  resource_group_name      = azurerm_resource_group.example.name
  location                 = azurerm_resource_group.example.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  is_hns_enabled           = "true"
}

resource "azurerm_storage_container" "example" {
  name                  = "datasets"
  storage_account_name  = azurerm_storage_account.example.name
  container_access_type = "private"
}

# Create a secret to store azure storage account key and connection string
resource "kubernetes_secret" "storage" {
  metadata {
    name      = "mystoragesecret"
    namespace = kubernetes_namespace.example.metadata[0].name
  }

  type = "Opaque"

  data = {
    "connectionString" = azurerm_storage_account.example.primary_connection_string
    "accountKey"       = azurerm_storage_account.example.primary_access_key
  }
}