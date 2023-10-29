resource "azurerm_kubernetes_cluster" "example" {
  name                = "aks-${local.name}"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  dns_prefix          = "aks-${local.name}"

  default_node_pool {
    name                        = "system"
    temporary_name_for_rotation = "tempsystem"
    vm_size                     = var.vm_size
    node_count                  = var.node_count
    os_sku                      = var.os_sku
    vnet_subnet_id              = azurerm_subnet.aks.id
  }

  network_profile {
    network_plugin = "azure"
    network_policy = "azure"
  }

  identity {
    type = "SystemAssigned"
  }

  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  lifecycle {
    ignore_changes = [
      monitor_metrics,
      azure_policy_enabled,
      microsoft_defender
    ]
  }
}

resource "null_resource" "wait_for_aks" {
  provisioner "local-exec" {
    command = "sleep 120"
  }

  depends_on = [azurerm_kubernetes_cluster.example]
}

resource "local_file" "kubeconfig" {
  filename = "mykubeconfig"
  content  = azurerm_kubernetes_cluster.example.kube_config_raw
}
