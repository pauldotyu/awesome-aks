resource "azurerm_user_assigned_identity" "control_cert_manager" {
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  name                = "control-cert-manager"
}

resource "azurerm_role_assignment" "control_cert_manager" {
  principal_id                     = azurerm_user_assigned_identity.control_cert_manager.principal_id
  scope                            = azurerm_dns_zone.example.id
  role_definition_name             = "DNS Zone Contributor"
  skip_service_principal_aad_check = true
}

resource "azurerm_federated_identity_credential" "control_cert_manager" {
  user_assigned_identity_id = azurerm_user_assigned_identity.control_cert_manager.id
  name                      = "control-cert-manager"
  issuer                    = azurerm_kubernetes_cluster.control.oidc_issuer_url
  audience                  = ["api://AzureADTokenExchange"]
  subject                   = "system:serviceaccount:cert-manager:cert-manager"
}

# See https://github.com/cert-manager/cert-manager/releases for latest
resource "helm_release" "control_cert_manager" {
  name             = "cert-manager"
  chart            = "oci://quay.io/jetstack/charts/cert-manager"
  version          = "v1.21.2"
  namespace        = "cert-manager"
  create_namespace = true

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
      value = azurerm_user_assigned_identity.control_cert_manager.client_id
      type  = "string"
    }
  ]

  depends_on = [
    azurerm_federated_identity_credential.control_cert_manager,
    azurerm_role_assignment.control_cert_manager,
    azurerm_role_assignment.control_cluster_access,
  ]
}

resource "local_file" "control_cert_manager" {
  filename = "kubernetes/control/cert-manager.yaml"
  content = templatefile("cert-manager.tmpl",
    {
      ADMIN_EMAIL                     = var.admin_email
      RG_NAME                         = azurerm_resource_group.example.name
      SUBSCRIPTION_ID                 = data.azurerm_client_config.current.subscription_id
      DNS_ZONE_NAME                   = azurerm_dns_zone.example.name
      CERT_MANAGER_IDENTITY_CLIENT_ID = azurerm_user_assigned_identity.control_cert_manager.client_id
    }
  )
}

resource "azurerm_user_assigned_identity" "worker_cert_manager" {
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  name                = "worker-cert-manager"
}

resource "azurerm_role_assignment" "worker_cert_manager" {
  principal_id                     = azurerm_user_assigned_identity.worker_cert_manager.principal_id
  scope                            = azurerm_dns_zone.example.id
  role_definition_name             = "DNS Zone Contributor"
  skip_service_principal_aad_check = true
}

resource "azurerm_federated_identity_credential" "worker_cert_manager" {
  user_assigned_identity_id = azurerm_user_assigned_identity.worker_cert_manager.id
  name                      = "worker-cert-manager"
  issuer                    = azapi_resource.aks_worker.output.properties.oidcIssuerProfile.issuerURL
  audience                  = ["api://AzureADTokenExchange"]
  subject                   = "system:serviceaccount:cert-manager:cert-manager"
}

# See https://github.com/cert-manager/cert-manager/releases for latest
resource "helm_release" "worker_cert_manager" {
  provider         = helm.worker
  name             = "cert-manager"
  chart            = "oci://quay.io/jetstack/charts/cert-manager"
  version          = "v1.21.2"
  namespace        = "cert-manager"
  create_namespace = true

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
      value = azurerm_user_assigned_identity.worker_cert_manager.client_id
      type  = "string"
    },
    {
      name  = "global.leaderElection.namespace"
      value = "cert-manager"
    }
  ]

  depends_on = [
    azurerm_federated_identity_credential.worker_cert_manager,
    azurerm_role_assignment.worker_cert_manager,
    azurerm_role_assignment.worker_cluster_access,
    azapi_update_resource.aks_ds_ns_exclusion
  ]
}

resource "local_file" "worker_cert_manager" {
  filename = "kubernetes/worker/cert-manager.yaml"
  content = templatefile("cert-manager.tmpl",
    {
      ADMIN_EMAIL                     = var.admin_email
      RG_NAME                         = azurerm_resource_group.example.name
      SUBSCRIPTION_ID                 = data.azurerm_client_config.current.subscription_id
      DNS_ZONE_NAME                   = azurerm_dns_zone.example.name
      CERT_MANAGER_IDENTITY_CLIENT_ID = azurerm_user_assigned_identity.worker_cert_manager.client_id
    }
  )
}