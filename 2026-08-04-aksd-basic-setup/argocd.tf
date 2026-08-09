resource "azapi_update_resource" "aks_ds_ns_exclusion" {
  type        = "Microsoft.ContainerService/deploymentSafeguards@2025-05-02-preview"
  resource_id = "${azapi_resource.aks.id}/providers/Microsoft.ContainerService/deploymentSafeguards/default"

  body = {
    properties = {
      excludedNamespaces = [
        "argocd"
      ]
    }
  }
}

resource "azurerm_kubernetes_cluster_extension" "argocd" {
  name           = "argocd"
  cluster_id     = azapi_resource.aks.id
  extension_type = "Microsoft.ArgoCD"
  release_train  = "Preview"

  depends_on = [
    azapi_update_resource.aks_ds_ns_exclusion
  ]
}