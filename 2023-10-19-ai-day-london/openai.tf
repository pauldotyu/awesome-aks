resource "azurerm_cognitive_account" "example" {
  name                  = "aoai-${local.name}"
  location              = var.ai_location
  resource_group_name   = azurerm_resource_group.example.name
  kind                  = "OpenAI"
  sku_name              = "S0"
  custom_subdomain_name = "aoai-${local.name}"
}

resource "azurerm_cognitive_deployment" "gpt35" {
  name                 = "gpt-35-turbo"
  cognitive_account_id = azurerm_cognitive_account.example.id
  rai_policy_name      = "Microsoft.Default"

  model {
    format  = "OpenAI"
    name    = "gpt-35-turbo"
    version = "0613"
  }

  scale {
    type     = "Standard"
    capacity = 120
  }
}

resource "azurerm_cognitive_deployment" "gpt4" {
  count                = var.deploy_gpt4 ? 1 : 0
  name                 = "gpt-4"
  cognitive_account_id = azurerm_cognitive_account.example.id

  model {
    format  = "OpenAI"
    name    = "gpt-4"
    version = "0613"
  }

  scale {
    type     = "Standard"
    capacity = 40
  }
}

resource "azurerm_user_assigned_identity" "example" {
  location            = var.ai_location
  name                = "aoai-${local.name}"
  resource_group_name = azurerm_resource_group.example.name
}

resource "azurerm_federated_identity_credential" "example" {
  name                = "aoai-${local.name}"
  resource_group_name = azurerm_resource_group.example.name
  parent_id           = azurerm_user_assigned_identity.example.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.example.oidc_issuer_url
  subject             = "system:serviceaccount:${var.k8s_namespace}:ai-service-account"
}

resource "azurerm_role_assignment" "example_aoai_me" {
  principal_id         = data.azurerm_client_config.current.object_id
  role_definition_name = "Cognitive Services OpenAI User"
  scope                = azurerm_cognitive_account.example.id
}

resource "azurerm_role_assignment" "example_aoai_mi" {
  principal_id         = azurerm_user_assigned_identity.example.principal_id
  role_definition_name = "Cognitive Services OpenAI User"
  scope                = azurerm_cognitive_account.example.id
}

resource "null_resource" "wait_for_flux" {
  depends_on = [
    azurerm_kubernetes_flux_configuration.example
  ]

  provisioner "local-exec" {
    command = "sleep 120"
  }
}

resource "kubernetes_service_account" "example" {
  metadata {
    name      = "ai-service-account"
    namespace = var.k8s_namespace

    annotations = {
      "azure.workload.identity/client-id" = azurerm_user_assigned_identity.example.client_id
    }
  }

  depends_on = [
    local_file.kubeconfig,
    null_resource.wait_for_flux
  ]
}

# resource "kubernetes_config_map" "example" {
#   metadata {
#     name      = "ai-service-configmap"
#     namespace = var.k8s_namespace
#   }

#   data = {
#     USE_AZURE_OPENAI             = "True"
#     USE_AZURE_AD                 = "True"
#     AZURE_OPENAI_DEPLOYMENT_NAME = "gpt-35-turbo"
#     AZURE_OPENAI_ENDPOINT        = azurerm_cognitive_account.example.endpoint
#   }

#   depends_on = [
#     local_file.kubeconfig,
#     null_resource.wait_for_flux
#   ]
# }

// Deploy kube-copilot with helm which uses the gpt4 model
resource "helm_release" "kube-copilot" {
  count           = var.deploy_gpt4 ? 1 : 0
  name            = "kube-copilot"
  chart           = "kube-copilot"
  repository      = "https://feisky.xyz/kube-copilot"
  cleanup_on_fail = true

  set {
    name  = "openai.apiModel"
    value = "gpt-4"
  }

  set {
    name  = "openai.apiKey"
    value = azurerm_cognitive_account.example.primary_access_key
  }

  set {
    name  = "openai.apiBase"
    value = azurerm_cognitive_account.example.endpoint
  }
}