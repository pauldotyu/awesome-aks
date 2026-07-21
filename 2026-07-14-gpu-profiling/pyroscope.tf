resource "helm_release" "pyroscope_operator" {
  name      = "pyroscope"
  chart     = "oci://ghcr.io/grafana/helm-charts/pyroscope"
  version   = "1.15.0"
  namespace = "gadget"

  set = concat(
    [
      {
        name  = "pyroscope.image.repository"
        value = "grafana/pyroscope"
      },
      {
        name  = "pyroscope.image.tag"
        value = "1.15.0"
        type  = "string"
      },
      {
        name  = "pyroscope.replicaCount"
        value = "1"
      },
      {
        name  = "pyroscope.structuredConfig.self_profiling.disable_push"
        value = "true"
      },
      {
        name  = "pyroscope.structuredConfig.storage.backend"
        value = "filesystem"
      },
      {
        name  = "pyroscope.service.type"
        value = "LoadBalancer"
      },
      {
        name  = "pyroscope.service.port"
        value = "4040"
      },
      {
        name  = "pyroscope.service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-internal"
        value = "true"
        type  = "string"
      },
      {
        name  = "pyroscope.service.annotations.service\\.beta\\.kubernetes\\.io/azure-pls-create"
        value = "true"
        type  = "string"
      },
      {
        name  = "pyroscope.service.annotations.service\\.beta\\.kubernetes\\.io/azure-pls-name"
        value = "pyroscope-pls"
        type  = "string"
      },
      {
        name  = "pyroscope.service.annotations.service\\.beta\\.kubernetes\\.io/azure-pls-proxy-protocol"
        value = "false"
        type  = "string"
      },
      {
        name  = "pyroscope.service.annotations.service\\.beta\\.kubernetes\\.io/azure-pls-visibility"
        value = "*"
        type  = "string"
      },
      {
        name  = "alloy.enabled"
        value = "false"
      },
      {
        name  = "minio.enabled"
        value = "false"
      }
    ]
  )

  depends_on = [
    azurerm_kubernetes_cluster_extension.ig_operator
  ]
}

resource "time_sleep" "wait_for_pyroscope_pls" {
  create_duration = "180s"

  depends_on = [
    helm_release.pyroscope_operator
  ]
}


data "azurerm_private_link_service" "example" {
  resource_group_name = azurerm_kubernetes_cluster.example.node_resource_group
  name                = "pyroscope-pls"

  depends_on = [
    time_sleep.wait_for_pyroscope_pls
  ]
}

resource "azurerm_dashboard_grafana_managed_private_endpoint" "example" {
  grafana_id               = azurerm_dashboard_grafana.example.id
  name                     = "pyroscope-mpe"
  location                 = data.azurerm_private_link_service.example.location
  private_link_resource_id = data.azurerm_private_link_service.example.id
}

locals {
  private_link_service_parent_id = trimsuffix(
    data.azurerm_private_link_service.example.id,
    "/providers/Microsoft.Network/privateLinkServices/${data.azurerm_private_link_service.example.name}"
  )
}

data "azapi_resource" "pyroscope_private_link_service" {
  type      = "Microsoft.Network/privateLinkServices@2023-09-01"
  name      = data.azurerm_private_link_service.example.name
  parent_id = local.private_link_service_parent_id

  response_export_values = [
    "properties.privateEndpointConnections"
  ]

  depends_on = [
    azurerm_dashboard_grafana_managed_private_endpoint.example
  ]
}

locals {
  private_endpoint_connection_name = one([
    for connection in data.azapi_resource.pyroscope_private_link_service.output.properties.privateEndpointConnections
    : connection.name
    if endswith(connection.properties.privateEndpoint.id, "grafana-${azurerm_dashboard_grafana.example.name}-${azurerm_dashboard_grafana_managed_private_endpoint.example.name}")
  ])
}

# https://learn.microsoft.com/en-us/azure/templates/microsoft.dashboard/grafana/managedprivateendpoints?pivots=deployment-language-terraform
resource "azapi_update_resource" "grafana_managed_private_endpoint_connection_approval" {
  type      = "Microsoft.Network/privateLinkServices/privateEndpointConnections@2023-09-01"
  name      = local.private_endpoint_connection_name
  parent_id = data.azurerm_private_link_service.example.id

  body = {
    properties = {
      privateLinkServiceConnectionState = {
        actionsRequired = "None"
        description     = "Approved via Terraform"
        status          = "Approved"
      }
    }
  }

  depends_on = [
    data.azapi_resource.pyroscope_private_link_service
  ]
}

resource "time_sleep" "wait_for_pls_approval" {
  create_duration = "180s"
  depends_on      = [
    azapi_update_resource.grafana_managed_private_endpoint_connection_approval
  ]
}

# https://learn.microsoft.com/en-us/rest/api/managed-grafana/managed-private-endpoints/refresh?view=rest-managed-grafana-2025-08-01&tabs=HTTP
resource "azapi_resource_action" "grafana_managed_private_endpoint_refresh" {
  type        = "Microsoft.Dashboard/grafana@2026-05-01-preview"
  resource_id = azurerm_dashboard_grafana.example.id
  action      = "refreshManagedPrivateEndpoints"

  depends_on = [
    time_sleep.wait_for_pls_approval
  ]
}

data "azapi_resource" "pyroscope_managed_private_endpoint" {
  type      = "Microsoft.Dashboard/grafana/managedPrivateEndpoints@2025-09-01-preview"
  name      = azurerm_dashboard_grafana_managed_private_endpoint.example.name
  parent_id = azurerm_dashboard_grafana.example.id

  response_export_values = [
    "properties.privateLinkServicePrivateIP"
  ]

  depends_on = [
    azapi_resource_action.grafana_managed_private_endpoint_refresh
  ]
}