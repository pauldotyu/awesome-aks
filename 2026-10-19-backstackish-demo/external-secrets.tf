resource "azurerm_user_assigned_identity" "external_secrets" {
  resource_group_name = azurerm_resource_group.example.name
  name                = "external-secrets"
  location            = azurerm_resource_group.example.location
}

resource "azurerm_role_assignment" "external_secrets_kv" {
  principal_id                     = azurerm_user_assigned_identity.external_secrets.principal_id
  scope                            = azurerm_key_vault.backstage.id
  role_definition_name             = "Key Vault Secrets User"
  skip_service_principal_aad_check = true
}

resource "azurerm_federated_identity_credential" "external_secrets" {
  user_assigned_identity_id = azurerm_user_assigned_identity.external_secrets.id
  name                      = "external-secrets"
  issuer                    = azurerm_kubernetes_cluster.control.oidc_issuer_url
  audience                  = ["api://AzureADTokenExchange"]
  subject                   = "system:serviceaccount:external-secrets:external-secrets"
}

resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  chart            = "oci://ghcr.io/external-secrets/charts/external-secrets"
  version          = var.external_secrets_version
  namespace        = "external-secrets"
  create_namespace = true
  wait             = true
  wait_for_jobs    = true
  timeout          = 300

  set = [
    {
      name  = "installCRDs"
      value = "true"
    },
    {
      name  = "crds.annotations.helm\\.sh/resource-policy"
      value = "keep"
      type  = "string"
    },
    {
      name  = "serviceAccount.annotations.azure\\.workload\\.identity/client-id"
      value = azurerm_user_assigned_identity.external_secrets.client_id
      type  = "string"
    },
    {
      name  = "serviceAccount.annotations.azure\\.workload\\.identity/tenant-id"
      value = data.azurerm_client_config.current.tenant_id
      type  = "string"
    },
    {
      name  = "podLabels.azure\\.workload\\.identity/use"
      value = "true"
      type  = "string"
    },
  ]

  depends_on = [
    azurerm_federated_identity_credential.external_secrets,
    azurerm_role_assignment.external_secrets_kv,
    azurerm_role_assignment.control_cluster_access,
  ]
}