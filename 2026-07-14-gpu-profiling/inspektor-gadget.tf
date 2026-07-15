resource "azurerm_kubernetes_cluster_extension" "ig_operator" {
  name           = "inspektor-gadget"
  cluster_id     = azurerm_kubernetes_cluster.example.id
  extension_type = "microsoft.inspektorgadget"
  release_train  = "preview"

  configuration_settings = {
    "gpuObservability.enabled" = "true"
    "azureMonitor.enabled"     = "true"
  }

  depends_on = [
    azurerm_monitor_data_collection_rule_association.dcr1,
    azurerm_monitor_data_collection_rule_association.dcr2,
    azurerm_monitor_data_collection_rule_association.msci
  ]
}