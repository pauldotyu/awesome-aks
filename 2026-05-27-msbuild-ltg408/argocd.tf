locals {
  oidc_config = <<EOT
name: Microsoft Entra ID
issuer: https://login.microsoftonline.com/${data.azuread_client_config.current.tenant_id}/v2.0
clientID: ${azuread_application.example.client_id}
azure:
  useWorkloadIdentity: true
requestedIDTokenClaims:
  groups:
    essential: true
requestedScopes:
  - openid
  - profile
  - email
EOT

  policy_csv = <<EOT
g, "${data.azuread_group.example.object_id}", role:admin
EOT
}

resource "azurerm_kubernetes_cluster_extension" "argocd" {
  name           = "argocd"
  cluster_id     = azapi_resource.aks.id
  extension_type = "Microsoft.ArgoCD"
  release_train  = "Preview"

  configuration_settings = {
    "azure.workloadIdentity.enabled"                = "true"
    "azure.workloadIdentity.clientId"               = azuread_application.example.client_id
    "azure.workloadIdentity.entraSSOClientId"       = azuread_application.example.client_id
    "redis-ha.enabled"                              = "false"
    "global.domain"                                 = "localhost:8080"
    "configs.cm.admin\\.enabled"                    = "false"
    "configs.cm.oidc\\.config"                      = local.oidc_config
    "configs.rbac.policy\\.csv"                     = local.policy_csv
    "redisSecretInit.resources.limits.cpu"          = "200m"
    "redisSecretInit.resources.limits.memory"       = "128Mi"
    "redisSecretInit.resources.requests.cpu"        = "100m"
    "redisSecretInit.resources.requests.memory"     = "64Mi"
    "repoServer.copyutil.resources.limits.cpu"      = "100m"
    "repoServer.copyutil.resources.limits.memory"   = "128Mi"
    "repoServer.copyutil.resources.requests.cpu"    = "50m"
    "repoServer.copyutil.resources.requests.memory" = "64Mi"
    "dex.enabled"                                   = "false"
    # "dex.resources.limits.cpu"                      = "50m"
    # "dex.resources.limits.memory"                   = "64Mi"
    # "dex.resources.requests.cpu"                    = "10m"
    # "dex.resources.requests.memory"                 = "32Mi"
  }
}