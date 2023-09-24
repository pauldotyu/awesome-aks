output "aks_name" {
  value = azurerm_kubernetes_cluster.example.name
}

output "rg_name" {
  value = azurerm_resource_group.example.name
}

output "amg_endpoint" {
  value = azurerm_dashboard_grafana.example.endpoint
}

output "istio_ingress_ip" {
  value = data.kubernetes_service.example.status.0.load_balancer.0.ingress.0.ip
}

output "amon_name" {
  value = azurerm_monitor_workspace.example.name
}
