resource "azurerm_kubernetes_cluster_extension" "ig_operator" {
  name           = "inspektor-gadget"
  cluster_id     = azapi_resource.aks.id
  extension_type = "microsoft.inspektorgadget"
  release_train  = "preview"

  configuration_settings = {
    "gpuObservability.enabled" = "true"
    "azureMonitor.enabled"     = "true"
  }

  depends_on = [
    azapi_update_resource.aks_ds_ns_exclusion,
    azurerm_monitor_data_collection_rule_association.dcr1,
    azurerm_monitor_data_collection_rule_association.dcr2,
    azurerm_monitor_data_collection_rule_association.msci
  ]
}