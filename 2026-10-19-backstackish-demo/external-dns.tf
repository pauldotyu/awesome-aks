resource "azurerm_user_assigned_identity" "control_external_dns" {
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  name                = "control-external-dns"
}

resource "azurerm_role_assignment" "control_external_dns" {
  principal_id                     = azurerm_user_assigned_identity.control_external_dns.principal_id
  scope                            = azurerm_dns_zone.example.id
  role_definition_name             = "DNS Zone Contributor"
  skip_service_principal_aad_check = true
}

resource "azurerm_federated_identity_credential" "control_external_dns" {
  user_assigned_identity_id = azurerm_user_assigned_identity.control_external_dns.id
  name                      = "external-dns"
  issuer                    = azurerm_kubernetes_cluster.control.oidc_issuer_url
  audience                  = ["api://AzureADTokenExchange"]
  subject                   = "system:serviceaccount:external-dns:external-dns"
}

resource "local_file" "control_external_dns" {
  filename = "kubernetes/control/external-dns.yaml"
  content = templatefile("external-dns.tmpl",
    {
      DNS_ZONE_RESOURCE_ID            = azurerm_dns_zone.example.id
      DNS_ZONE_NAME                   = replace(azurerm_dns_zone.example.name, ".", "-")
      EXTERNAL_DNS_IDENTITY_CLIENT_ID = azurerm_user_assigned_identity.control_external_dns.client_id
    }
  )
}

resource "azurerm_user_assigned_identity" "worker_external_dns" {
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  name                = "worker-external-dns"
}

resource "azurerm_federated_identity_credential" "worker_external_dns" {
  user_assigned_identity_id = azurerm_user_assigned_identity.worker_external_dns.id
  name                      = "worker-external-dns"
  issuer                    = azapi_resource.aks_worker.output.properties.oidcIssuerProfile.issuerURL
  audience                  = ["api://AzureADTokenExchange"]
  subject                   = "system:serviceaccount:external-dns:external-dns"
}

resource "azurerm_role_assignment" "worker_external_dns" {
  principal_id                     = azurerm_user_assigned_identity.worker_external_dns.principal_id
  scope                            = azurerm_dns_zone.example.id
  role_definition_name             = "DNS Zone Contributor"
  skip_service_principal_aad_check = true
}

resource "local_file" "worker_external_dns" {
  filename = "kubernetes/worker/external-dns.yaml"
  content = templatefile("external-dns.tmpl",
    {
      DNS_ZONE_RESOURCE_ID            = azurerm_dns_zone.apps.id
      DNS_ZONE_NAME                   = replace(azurerm_dns_zone.apps.name, ".", "-")
      EXTERNAL_DNS_IDENTITY_CLIENT_ID = azurerm_user_assigned_identity.worker_external_dns.client_id
    }
  )
}