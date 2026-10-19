# ---------------------------------------------------------------------------
# External Secrets Operator -> Azure Key Vault -> backstage-secrets
#
# ESO materializes the four Key Vault secrets into a native Kubernetes Secret
# named `backstage-secrets` in the OpenChoreo control-plane namespace. This is
# the Azure-native secret store (replacing OpenBao from the upstream
# getting-started chart). ESO authenticates to Key Vault with the
# `external-secrets` Workload Identity defined in key-vault.tf; the controller
# service account is annotated with that client-id and labelled so the AKS
# aad-pod-identity webhook projects the token.
# ---------------------------------------------------------------------------

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
  ]
}

# ClusterSecretStore + ExternalSecret, applied with kubectl (the Kubernetes
# Terraform provider needs a live cluster connection at plan time and the AKS
# cluster is created by this same apply).
resource "local_file" "backstage_secrets" {
  filename = "backstage-secrets.yaml"
  content = templatefile("${path.module}/files/backstage-secrets.yaml.tpl", {
    vault_url                = azurerm_key_vault.example.vault_uri
    tenant_id                = data.azurerm_client_config.current.tenant_id
    namespace                = local.openchoreo_namespace
    kv_backend_secret        = azurerm_key_vault_secret.backstage_backend_secret.name
    kv_client_secret         = azurerm_key_vault_secret.backstage_client_secret.name
    kv_service_client_secret = azurerm_key_vault_secret.backstage_service_client_secret.name
    kv_jenkins_api_key       = azurerm_key_vault_secret.backstage_jenkins_api_key.name
  })
}

resource "terraform_data" "backstage_secrets" {
  input = {
    manifest = local_file.backstage_secrets.content
  }

  provisioner "local-exec" {
    command = "bash ${path.module}/files/kubectl-apply.sh"
    environment = {
      KUBECONFIG_FILE = local_file.kubeconfig.filename
      MANIFEST_FILE   = local_file.backstage_secrets.filename
    }
  }

  depends_on = [
    helm_release.external_secrets,
    terraform_data.openchoreo_namespace,
    local_file.kubeconfig,
    azurerm_key_vault_secret.backstage_backend_secret,
    azurerm_key_vault_secret.backstage_client_secret,
    azurerm_key_vault_secret.backstage_service_client_secret,
    azurerm_key_vault_secret.backstage_jenkins_api_key,
  ]
}
