resource "helm_release" "crossplane" {
  name             = "crossplane"
  repository       = "https://charts.crossplane.io/stable"
  chart            = "crossplane"
  version          = "2.4.2"
  namespace        = "crossplane-system"
  create_namespace = true

  depends_on = [azurerm_role_assignment.control_cluster_access]
}

resource "azurerm_storage_account" "opentofu" {
  name                            = "st${local.random_unique_name}"
  resource_group_name             = azurerm_resource_group.example.name
  location                        = azurerm_resource_group.example.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  default_to_oauth_authentication = true
  shared_access_key_enabled       = false
}

resource "azurerm_storage_container" "opentofu" {
  name               = "tfstate"
  storage_account_id = azurerm_storage_account.opentofu.id
}

resource "azurerm_user_assigned_identity" "opentofu" {
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  name                = "provider-opentofu"
}

resource "azurerm_role_assignment" "opentofu_storage_blob_data_contributor" {
  principal_id                     = azurerm_user_assigned_identity.opentofu.principal_id
  scope                            = azurerm_storage_account.opentofu.id
  role_definition_name             = "Storage Blob Data Contributor"
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "opentofu_contributor" {
  principal_id                     = azurerm_user_assigned_identity.opentofu.principal_id
  scope                            = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
  role_definition_name             = "Contributor"
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "opentofu_rbac_administrator" {
  principal_id                     = azurerm_user_assigned_identity.opentofu.principal_id
  scope                            = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
  role_definition_name             = "Role Based Access Control Administrator"
  skip_service_principal_aad_check = true
}

resource "azurerm_federated_identity_credential" "crossplane" {
  user_assigned_identity_id = azurerm_user_assigned_identity.opentofu.id
  name                      = "provider-opentofu"
  issuer                    = azurerm_kubernetes_cluster.control.oidc_issuer_url
  audience                  = ["api://AzureADTokenExchange"]
  subject                   = "system:serviceaccount:crossplane-system:provider-opentofu"
}


resource "local_file" "crossplane_provider_opentofu" {
  filename = "kubernetes/crossplane.yaml"
  content = templatefile("crossplane.tmpl",
    {

      PROVISIONER_CLIENT_ID     = azurerm_user_assigned_identity.opentofu.client_id
      AZURE_TENANT_ID           = data.azuread_client_config.current.tenant_id
      AZURE_SUBSCRIPTION_ID     = data.azurerm_client_config.current.subscription_id
      PROVIDER_OPENTOFU_VERSION = var.crossplane_provider_opentofu_version
    }
  )
}

resource "local_file" "opentofu_config" {
  filename = "kubernetes/opentofu-state.yaml"
  content = templatefile("opentofu-state.tmpl",
    {

      PROVISIONER_CLIENT_ID = azurerm_user_assigned_identity.opentofu.client_id
      AZURE_TENANT_ID       = data.azuread_client_config.current.tenant_id
      AZURE_SUBSCRIPTION_ID = data.azurerm_client_config.current.subscription_id
      RESOURCE_GROUP_NAME   = azurerm_resource_group.example.name
      STORAGE_ACCOUNT_NAME  = azurerm_storage_account.opentofu.name
      CONTAINER_NAME        = azurerm_storage_container.opentofu.name
    }
  )
}