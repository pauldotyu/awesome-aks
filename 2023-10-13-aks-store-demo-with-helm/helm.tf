resource "helm_release" "example" {
  name             = "aks-store-demo"
  repository       = "oci://ghcr.io/pauldotyu"
  chart            = "aks-store-demo-chart"
  version          = "0.1.0"
  namespace        = var.k8s_namespace
  create_namespace = true
  wait             = false

  set {
    name  = "aiService.create"
    value = "true"
  }

  set {
    name  = "aiService.modelDeploymentName"
    value = azurerm_cognitive_deployment.example.name
  }

  set {
    name  = "aiService.openAiEndpoint"
    value = azurerm_cognitive_account.example.endpoint
  }

  set {
    name  = "aiService.managedIdentityClientId"
    value = azurerm_user_assigned_identity.example.client_id
  }

  depends_on = [azapi_update_resource.example]
}