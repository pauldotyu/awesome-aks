resource "azurerm_kubernetes_cluster" "example" {
  name                = "aks-${local.random_name}"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  dns_prefix          = "aks-${local.random_name}"
  kubernetes_version  = "1.35"

  default_node_pool {
    name                 = "default"
    min_count            = 3
    max_count            = 6
    auto_scaling_enabled = true
    vm_size              = "Standard_D4d_v4"
    vnet_subnet_id       = azurerm_subnet.aks_default.id

    upgrade_settings {
      drain_timeout_in_minutes      = 0
      max_surge                     = "10%"
      node_soak_duration_in_minutes = 0
    }
  }

  identity {
    type = "SystemAssigned"
  }
}

# When you're ready to add the inference node pool, uncomment the following code and run `terraform apply` again.
# Make sure to adjust the VM size and node count as needed for your workload.
# resource "azurerm_kubernetes_cluster_node_pool" "inference" {
#   name                        = "inference"
#   kubernetes_cluster_id       = azurerm_kubernetes_cluster.example.id
#   vm_size                     = "Standard_NC48ads_A100_v4"
#   node_count                  = 1
#   min_count                   = 1
#   max_count                   = 1
#   auto_scaling_enabled        = true
#   gpu_driver                  = "None"
#   vnet_subnet_id              = azurerm_subnet.aks_inference.id
#   temporary_name_for_rotation = "temp${random_integer.example.result}"

#   upgrade_settings {
#     drain_timeout_in_minutes      = 0
#     max_surge                     = "10%"
#     node_soak_duration_in_minutes = 0
#   }

#   depends_on = [
#     azurerm_kubernetes_cluster.example,
#     helm_release.nvidia_gpu_operator,
#     helm_release.istio_base,
#     helm_release.istiod,
#     helm_release.argo_cd
#   ]
# }