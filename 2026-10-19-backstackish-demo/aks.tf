resource "azurerm_kubernetes_cluster" "control" {
  name                              = local.aks_control_name
  location                          = azurerm_resource_group.example.location
  resource_group_name               = azurerm_resource_group.example.name
  dns_prefix                        = local.aks_control_name
  kubernetes_version                = var.control_kubernetes_version
  sku_tier                          = "Free"
  oidc_issuer_enabled               = true
  workload_identity_enabled         = true
  local_account_disabled            = true
  role_based_access_control_enabled = true
  automatic_upgrade_channel         = "patch"
  node_os_upgrade_channel           = "NodeImage"

  azure_active_directory_role_based_access_control {
    tenant_id          = data.azurerm_client_config.current.tenant_id
    azure_rbac_enabled = true
  }

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = var.control_vm_size

    upgrade_settings {
      drain_timeout_in_minutes      = 0
      max_surge                     = "10%"
      node_soak_duration_in_minutes = 0
    }
  }

  identity {
    type = "SystemAssigned"
  }

  node_provisioning_profile {
    mode = "Auto"
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_data_plane  = "cilium"
    network_policy      = "cilium"
    outbound_type       = "loadBalancer"
    load_balancer_sku   = "standard"
  }
}

resource "azapi_update_resource" "add_cluster_features" {
  type        = "Microsoft.ContainerService/managedClusters@2026-08-02-preview"
  resource_id = azurerm_kubernetes_cluster.control.id
  body = {
    properties = {
      ingressProfile = {
        gatewayAPI = {
          installation = "Standard"
        }
        webAppRouting = {
          enabled = true
          gatewayAPIImplementations = {
            appRoutingIstio = {
              mode = "Enabled"
            }
          }
        }
      }
    }
  }
}

resource "azurerm_role_assignment" "control_cluster_access" {
  scope                = azurerm_kubernetes_cluster.control.id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = data.azurerm_client_config.current.object_id
  principal_type       = "User"
}