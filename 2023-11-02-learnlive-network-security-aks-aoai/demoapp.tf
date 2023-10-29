resource "helm_release" "demoapp" {
  name             = "aks-store-demo"
  repository       = "oci://ghcr.io/pauldotyu"
  chart            = "aks-store-demo-chart"
  version          = "1.0.0"
  namespace        = var.k8s_namespace
  create_namespace = true
  wait             = false

  set {
    name  = "aiService.create"
    value = "true"
  }

  set {
    name  = "aiService.modelDeploymentName"
    value = azurerm_cognitive_deployment.gpt35.name
  }

  set {
    name  = "aiService.openAiEndpoint"
    value = azurerm_cognitive_account.example.endpoint
  }

  set {
    name  = "aiService.managedIdentityClientId"
    value = azurerm_user_assigned_identity.aoai.client_id
  }
}

// Sleep for 120 seconds to allow the demoapp to deploy
resource "null_resource" "wait_for_demoapp" {
  provisioner "local-exec" {
    command = "sleep 120"
  }

  depends_on = [
    helm_release.demoapp
  ]
}