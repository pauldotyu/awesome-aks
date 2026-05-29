// https://learn.microsoft.com/en-us/azure/templates/microsoft.containerservice/managedclusters/managednamespaces?pivots=deployment-language-terraform
resource "azapi_resource" "managed_namespace" {
  type      = "Microsoft.ContainerService/managedClusters/managedNamespaces@2026-03-02-preview"
  parent_id = azapi_resource.aks.id
  location  = azurerm_resource_group.example.location
  tags      = var.tags
  name      = "team-blue"

  // this required when azapi local schema check isn't aware of the latest api version
  schema_validation_enabled = false

  body = {
    properties = {
      adoptionPolicy = "Always"
      annotations = {
        project = "ltg408"
        owner   = "team-blue"
      }
      defaultNetworkPolicy = {
        egress  = "AllowAll"
        ingress = "AllowAll"
      }
      defaultResourceQuota = {
        cpuLimit      = "2000m"
        cpuRequest    = "2000m"
        memoryLimit   = "4096Mi"
        memoryRequest = "4096Mi"
      }
      deletePolicy = "Delete"
      labels = {
        "headlamp.dev/project-id"            = "team-blue"
        "headlamp.dev/project-managed-by"    = "aks-desktop"
        "aks-desktop/project-subscription"   = data.azurerm_client_config.current.subscription_id
        "aks-desktop/project-resource-group" = azurerm_resource_group.example.name
      }
    }
  }
}

resource "azurerm_role_assignment" "managed_namespace_contributor" {
  principal_id         = data.azurerm_client_config.current.object_id
  role_definition_name = "Azure Kubernetes Service Namespace Contributor"
  scope                = azapi_resource.managed_namespace.id
}

resource "azurerm_role_assignment" "managed_namespace_user" {
  principal_id         = data.azurerm_client_config.current.object_id
  role_definition_name = "Azure Kubernetes Service Namespace User"
  scope                = azapi_resource.managed_namespace.id
}