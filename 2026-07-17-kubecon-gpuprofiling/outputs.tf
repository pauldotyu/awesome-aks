output "rg_name" {
  value = azurerm_resource_group.example.name
}

output "aks_name" {
  value = azapi_resource.aks.name
}

output "node_resource_group" {
  value = azapi_resource.aks.output.properties.nodeResourceGroup
}

output "pyroscope_pls_id" {
  value = data.azurerm_private_link_service.example.id
}

output "anyscale_iam_client_id" {
  value = azurerm_user_assigned_identity.example.client_id
}

output "anyscale_cloud_name" {
  value = lower(azapi_resource.anyscale_cloud.id)
}

output "anyscale_cloud_id" {
  value = split("/", azapi_resource.anyscale_cloud.output.properties.ssoUrl)[4]
}

output "anyscale_cloud_sso_url" {
  value = azapi_resource.anyscale_cloud.output.properties.ssoUrl
}

output "anyscale_cloud_resource_id" {
  value = azapi_resource.anyscale_cloud_resource.output.properties.cloudResourceId
}

output "otlp_logs_endpoint" {
  value = azapi_resource.otel.output.properties.OTLPLogsEndpoint
}

output "otlp_metrics_endpoint" {
  value = azapi_resource.otel.output.properties.OTLPMetricsEndpoint
}

output "otlp_traces_endpoint" {
  value = azapi_resource.otel.output.properties.OTLPTracesEndpoint
}

output "grafana_name" {
  value = azurerm_dashboard_grafana.example.name
}

output "grafana_url" {
  value = azurerm_dashboard_grafana.example.endpoint
}

output "prometheus_endpoint" {
  value = azurerm_monitor_workspace.example.query_endpoint
}

output "pyroscope_url" {
  description = "In-cluster Pyroscope endpoint Grafana reaches over the managed private endpoint (private IP:4040)."
  value       = "http://${data.azapi_resource.pyroscope_managed_private_endpoint.output.properties.privateLinkServicePrivateIP}:4040"
}