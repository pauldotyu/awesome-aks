###################################
# AKS cluster with addons enabled #
###################################

# resource "azurerm_container_registry" "example" {
#   name                = "acr${local.name}"
#   resource_group_name = azurerm_resource_group.example.name
#   location            = azurerm_resource_group.example.location
#   sku                 = "Standard"
#   admin_enabled       = false
# }

# resource "azurerm_role_assignment" "example_acr_me" {
#   principal_id         = data.azurerm_client_config.current.object_id
#   role_definition_name = "Owner"
#   scope                = azurerm_container_registry.example.id
# }

resource "azurerm_kubernetes_cluster" "example" {
  name                = "aks-${local.name}"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  dns_prefix          = "aks-${local.name}"

  default_node_pool {
    name       = "system"
    vm_size    = "Standard_D4s_v4"
    node_count = 3

    # TODO: Find out why this combination breaks the rust apps
    #vm_size    = "Standard_B4s_v2"
    #os_sku     = "AzureLinux"
  }

  identity {
    type = "SystemAssigned"
  }

  monitor_metrics {
  }

  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "1m"
  }

  service_mesh_profile {
    mode                             = "Istio"
    external_ingress_gateway_enabled = true
    internal_ingress_gateway_enabled = true
  }

  workload_autoscaler_profile {
    keda_enabled = true
  }

  lifecycle {
    ignore_changes = [
      monitor_metrics,
      azure_policy_enabled,
      microsoft_defender
    ]
  }
}

# resource "azurerm_role_assignment" "example_aks_acr" {
#   principal_id                     = azurerm_kubernetes_cluster.example.kubelet_identity[0].object_id
#   role_definition_name             = "AcrPull"
#   scope                            = azurerm_container_registry.example.id
#   skip_service_principal_aad_check = true
# }

# resource "azurerm_kubernetes_cluster_node_pool" "example" {
#   name                  = "worker"
#   kubernetes_cluster_id = azurerm_kubernetes_cluster.example.id
#   vm_size               = "Standard_B4ps_v2"
#   os_sku                = "AzureLinux"
#   enable_auto_scaling   = true
#   min_count             = 3
#   max_count             = 10
# }

resource "null_resource" "wait_for_aks" {
  provisioner "local-exec" {
    command = "sleep 60"
  }

  depends_on = [azurerm_kubernetes_cluster.example]
}

resource "azapi_update_resource" "aks_network_observability" {
  type        = "Microsoft.ContainerService/managedClusters@2023-05-02-preview"
  resource_id = azurerm_kubernetes_cluster.example.id

  body = jsonencode({
    properties = {
      networkProfile = {
        monitoring = {
          enabled = true
        }
      }
    }
  })

  depends_on = [
    null_resource.wait_for_aks,
    azurerm_monitor_data_collection_rule_association.example_dce_to_aks,
    azurerm_monitor_data_collection_rule_association.example_dcr_to_aks,
    azurerm_monitor_alert_prometheus_rule_group.example_node,
    azurerm_monitor_alert_prometheus_rule_group.example_k8s,
  ]
}

resource "local_file" "kubeconfig" {
  filename = "mykubeconfig"
  content  = azurerm_kubernetes_cluster.example.kube_config_raw
}
