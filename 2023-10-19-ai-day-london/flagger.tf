#############################################
# Resources to support Flagger installation #
#############################################

resource "azuread_application" "example" {
  display_name = "sp-${local.name}"
  owners       = [data.azurerm_client_config.current.object_id]
}

resource "azuread_application_password" "example" {
  application_object_id = azuread_application.example.object_id
}

resource "azuread_service_principal" "example" {
  application_id               = azuread_application.example.application_id
  app_role_assignment_required = true
  owners                       = [data.azurerm_client_config.current.object_id]
}

resource "azurerm_role_assignment" "example" {
  scope                = azurerm_monitor_workspace.example.id
  role_definition_name = "Monitoring Data Reader"
  principal_id         = azuread_service_principal.example.object_id
}

resource "azuread_application_federated_identity_credential" "example" {
  application_object_id = azuread_application.example.object_id
  display_name          = "fc-${local.name}-flagger"
  audiences             = ["api://AzureADTokenExchange"]
  issuer                = azurerm_kubernetes_cluster.example.oidc_issuer_url
  subject               = "system:serviceaccount:aks-istio-system:flagger-sa"
}

resource "null_resource" "wait_for_aad_app" {
  provisioner "local-exec" {
    command = "sleep 180"
  }

  depends_on = [azuread_application.example]
}

data "http" "example_post" {
  url    = "https://login.microsoftonline.com/${data.azurerm_client_config.current.tenant_id}/oauth2/token"
  method = "POST"

  request_headers = {
    "Content-Type" = "application/x-www-form-urlencoded"
  }

  request_body = "grant_type=client_credentials&client_id=${azuread_application.example.application_id}&client_secret=${azuread_application_password.example.value}&resource=https://prometheus.monitor.azure.com"

  depends_on = [null_resource.wait_for_aad_app]
}

resource "kubernetes_namespace" "example" {
  metadata {
    name = "flagger"
  }

  depends_on = [
    azurerm_kubernetes_cluster_extension.example,
    data.http.example_post
  ]
}

resource "kubernetes_secret" "example_bearer_token" {
  metadata {
    name      = "prom-auth"
    namespace = "flagger"
  }

  data = {
    token = jsondecode(data.http.example_post.response_body).access_token
  }

  depends_on = [
    azurerm_kubernetes_cluster_extension.example,
    kubernetes_namespace.example,
  ]
}