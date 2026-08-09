output "rg_name" {
  description = "The name of the Resource Group"
  value       = azurerm_resource_group.example.name
}

output "aks_name" {
  description = "The name of the AKS cluster"
  value       = azapi_resource.aks.name
}


output "otel_logs_endpoint" {
  description = "The endpoint for OpenTelemetry logs"
  value       = azapi_resource.otel.output.properties.OTLPLogsEndpoint
}

output "otel_metrics_endpoint" {
  description = "The endpoint for OpenTelemetry metrics"
  value       = azapi_resource.otel.output.properties.OTLPMetricsEndpoint
}