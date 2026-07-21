output "rg_name" {
  value = azurerm_resource_group.example.name
}

output "aks_name" {
  value = azurerm_kubernetes_cluster.example.name
}

output "grafana_name" {
  value = azurerm_dashboard_grafana.example.name
}

output "prometheus_name" {
  value = azurerm_monitor_workspace.example.name
}

output "prometheus_endpoint" {
  value = azurerm_monitor_workspace.example.query_endpoint
}

output "pyroscope_url" {
  description = "In-cluster Pyroscope endpoint Grafana reaches over the managed private endpoint (private IP:4040)."
  value       = try("http://${data.azapi_resource.pyroscope_managed_private_endpoint.output.properties.privateLinkServicePrivateIP}:4040", "needs_refresh")
}