# ---------------------------------------------------------------------------
# cert-manager + Azure DNS DNS-01 validation via Azure Workload Identity
#
# Mirrors 2026-02-03-argocd-with-gateway/cert-manager.tf, pinned to v1.19.4,
# with both the pod label and service-account annotation set for workload
# identity (the AKS aad-pod-identity webhook would inject the label from the
# service-account annotation, but we set both explicitly to match the chart).
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Workload Identity for the cert-manager controller
# ---------------------------------------------------------------------------

resource "azurerm_user_assigned_identity" "cert_manager" {
  resource_group_name = azurerm_resource_group.example.name
  name                = "cert-manager-dns01"
  location            = azurerm_resource_group.example.location
}

# DNS Zone Contributor, scoped to the DNS zone only. cert-manager uses this to
# create/delete the _acme-challenge TXT records itself. The `azurerm.dns` alias
# targets the subscription that actually holds the zone.
resource "azurerm_role_assignment" "cert_manager_dns" {
  count = var.manage_cert_manager_dns_role ? 1 : 0

  provider                         = azurerm.dns
  principal_id                     = azurerm_user_assigned_identity.cert_manager.principal_id
  scope                            = local.dns_zone_id
  role_definition_name             = "DNS Zone Contributor"
  skip_service_principal_aad_check = true
}

resource "azurerm_federated_identity_credential" "cert_manager" {
  user_assigned_identity_id = azurerm_user_assigned_identity.cert_manager.id
  name                      = "cert-manager"
  issuer                    = azurerm_kubernetes_cluster.example.oidc_issuer_url
  audience                  = ["api://AzureADTokenExchange"]
  subject                   = "system:serviceaccount:cert-manager:cert-manager"
}

resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  chart            = "oci://quay.io/jetstack/charts/cert-manager"
  version          = var.cert_manager_version
  namespace        = "cert-manager"
  create_namespace = true
  wait             = true
  wait_for_jobs    = true
  timeout          = 300

  set = [
    {
      name  = "crds.enabled"
      value = "true"
    },
    {
      name  = "podLabels.azure\\.workload\\.identity/use"
      value = "true"
      type  = "string"
    },
    {
      name  = "serviceAccount.annotations.azure\\.workload\\.identity/client-id"
      value = azurerm_user_assigned_identity.cert_manager.client_id
      type  = "string"
    },
    {
      name  = "serviceAccount.annotations.azure\\.workload\\.identity/tenant-id"
      value = data.azurerm_client_config.current.tenant_id
      type  = "string"
    },
  ]

  depends_on = [
    azurerm_federated_identity_credential.cert_manager,
    azurerm_role_assignment.cert_manager_dns,
  ]
}

# ---------------------------------------------------------------------------
# Two ClusterIssuers: staging and production. Both are Azure DNS DNS-01 with
# Workload Identity. Only the one selected by var.letsencrypt_environment backs
# the cp-gateway-tls certificate; the other is left ready for the switch.
#
# Applied with kubectl (not the Kubernetes Terraform provider) because the
# provider needs a live cluster connection at plan time and the AKS cluster is
# created by this same apply.
# ---------------------------------------------------------------------------

resource "local_file" "letsencrypt_issuers" {
  filename = "letsencrypt-clusterissuers.yaml"
  content = templatefile("${path.module}/files/letsencrypt-clusterissuers.yaml.tpl", {
    subscription_id            = local.dns_zone_subscription_id
    resource_group_name        = local.dns_zone_resource_group_name
    hosted_zone_name           = var.dns_zone_name
    managed_identity_client_id = azurerm_user_assigned_identity.cert_manager.client_id
    email                      = var.letsencrypt_email
  })
}

resource "terraform_data" "letsencrypt_issuers" {
  input = {
    manifest = local_file.letsencrypt_issuers.content
  }

  provisioner "local-exec" {
    command = "bash ${path.module}/files/kubectl-apply.sh"
    environment = {
      KUBECONFIG_FILE = local_file.kubeconfig.filename
      MANIFEST_FILE   = local_file.letsencrypt_issuers.filename
    }
  }

  depends_on = [
    helm_release.cert_manager,
    # The cert-manager identity must be able to write TXT records in the zone
    # before any challenge is attempted. Referenced without an index so this
    # stays valid when var.manage_cert_manager_dns_role is false.
    azurerm_role_assignment.cert_manager_dns,
    local_file.kubeconfig,
  ]
}
