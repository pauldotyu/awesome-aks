provider "azurerm" {
  # Pin the environment subscription explicitly. The pre-existing Azure DNS zone
  # lives in a different subscription, and the environment must never end up
  # there — not even if the Azure CLI default subscription changes.
  #
  # null => fall back to the provider's default subscription.
  subscription_id = var.subscription_id != "" ? var.subscription_id : null

  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

# The Azure DNS zone that hosts the public names is pre-existing and lives in a
# different subscription. This alias is scoped to that subscription and is used
# ONLY to read the zone and (optionally) assign cert-manager the DNS Zone
# Contributor role on it. No other resource is created through this alias, so
# the environment itself is never deployed into the zone's subscription.
provider "azurerm" {
  alias = "dns"

  # null => fall back to the provider's default subscription.
  subscription_id = var.dns_zone_subscription_id != "" ? var.dns_zone_subscription_id : null

  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

provider "helm" {
  kubernetes = {
    host                   = azurerm_kubernetes_cluster.example.kube_config.0.host
    username               = azurerm_kubernetes_cluster.example.kube_config.0.username
    password               = azurerm_kubernetes_cluster.example.kube_config.0.password
    client_certificate     = base64decode(azurerm_kubernetes_cluster.example.kube_config.0.client_certificate)
    client_key             = base64decode(azurerm_kubernetes_cluster.example.kube_config.0.client_key)
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.example.kube_config.0.cluster_ca_certificate)
  }
}
