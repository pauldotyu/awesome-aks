resource "azurerm_private_dns_zone" "example" {
  name                = "privatelink.${var.location}.azmk8s.io"
  resource_group_name = azurerm_resource_group.example.name
}

# Destroy-only delay: AKS removes the DNS zone vnet link asynchronously after cluster deletion
resource "time_sleep" "dns_zone_deletion_delay" {
  depends_on = [azurerm_private_dns_zone.example]

  destroy_duration = "180s"
}

resource "azurerm_kubernetes_cluster" "example" {
  name                       = "aks-${local.random_name}"
  location                   = azurerm_resource_group.example.location
  resource_group_name        = azurerm_resource_group.example.name
  local_account_disabled     = false
  private_cluster_enabled    = true
  dns_prefix_private_cluster = "aks-${local.random_name}"
  private_dns_zone_id        = azurerm_private_dns_zone.example.id

  default_node_pool {
    name           = "system"
    node_count     = 3
    vm_size        = "Standard_D2ds_v5"
    vnet_subnet_id = azurerm_subnet.nodes.id

    upgrade_settings {
      drain_timeout_in_minutes      = 0
      max_surge                     = "10%"
      node_soak_duration_in_minutes = 0
    }
  }

  identity {
    type = "UserAssigned"
    identity_ids = [
      azurerm_user_assigned_identity.example.id
    ]
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_policy      = "cilium"
    network_data_plane  = "cilium"
  }

  node_provisioning_profile {
    mode = "Auto"
  }

  api_server_access_profile {
    subnet_id                           = azurerm_subnet.kubeapi.id
    virtual_network_integration_enabled = true
  }

  azure_active_directory_role_based_access_control {
    tenant_id              = data.azurerm_client_config.current.tenant_id
    admin_group_object_ids = [data.azurerm_client_config.current.object_id]
    azure_rbac_enabled     = true
  }

  depends_on = [time_sleep.dns_zone_deletion_delay]
}
