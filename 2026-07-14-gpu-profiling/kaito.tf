resource "azurerm_user_assigned_identity" "kaito" {
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  name                = "kaitoprovisioner"
}

resource "azurerm_role_assignment" "kaito_aks_contributor" {
  principal_id                     = azurerm_user_assigned_identity.kaito.principal_id
  scope                            = azurerm_kubernetes_cluster.example.id
  role_definition_name             = "Contributor"
  skip_service_principal_aad_check = true
}

resource "azurerm_federated_identity_credential" "kaito" {
  user_assigned_identity_id = azurerm_user_assigned_identity.kaito.id
  name                      = "kaitoprovisioner"
  issuer                    = azurerm_kubernetes_cluster.example.oidc_issuer_url
  audience                  = ["api://AzureADTokenExchange"]
  subject                   = "system:serviceaccount:gpu-provisioner:gpu-provisioner"
}

resource "helm_release" "gpu_provisioner" {
  name             = "gpu-provisioner"
  chart            = "https://raw.githubusercontent.com/Azure/gpu-provisioner/refs/heads/gh-pages/charts/gpu-provisioner-${var.kaito_gpu_provisioner_version}.tgz"
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

resource "helm_release" "kaito_workspace" {
  name             = "kaito-workspace"
  chart            = "https://raw.githubusercontent.com/kaito-project/kaito/refs/heads/gh-pages/charts/kaito/workspace-${var.kaito_workspace_version}.tgz"
  namespace        = "kaito-workspace"
  create_namespace = true

  set = concat(
    # [
    #   {
    #     name  = "image.repository"
    #     value = "ghcr.io/kaito-project/kaito/workspace"
    #   },
    #   {
    #     name  = "image.tag"
    #     value = "nightly-latest"
    #   }
    # ],
    [
      for feature in var.kaito_workspace_features : {
        name  = "featureGates.${feature}"
        value = "true"
      }
    ]
  )

}