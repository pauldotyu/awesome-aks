resource "azurerm_eventhub_namespace" "example" {
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  name                = "eh-${local.random_name}"
  sku                 = "Basic"
  capacity            = 1
}

resource "azurerm_eventhub" "example" {
  namespace_name      = azurerm_eventhub_namespace.example.name
  resource_group_name = azurerm_resource_group.example.name
  name                = "myeventhub"
  partition_count     = 1
  message_retention   = 1
}

resource "azurerm_monitor_action_group" "email" {
  name                = "ProductCounterActionGroupEmail"
  resource_group_name = azurerm_resource_group.example.name
  short_name          = "product"

  email_receiver {
    name          = "sendtoadmin"
    email_address = "pauyu@microsoft.com"
  }
}

resource "azurerm_monitor_action_group" "eventhub" {
  name                = "ProductCounterActionGroupEventHub"
  resource_group_name = azurerm_resource_group.example.name
  short_name          = "product"

  event_hub_receiver {
    event_hub_namespace     = azurerm_eventhub_namespace.example.name
    event_hub_name          = azurerm_eventhub.example.name
    name                    = "sendtoeventhub"
    use_common_alert_schema = false
  }
}

resource "azurerm_monitor_alert_prometheus_rule_group" "example" {
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  cluster_name        = azurerm_kubernetes_cluster.example.name
  name                = "ProductCounterRecordingRulesRuleGroup - ${azurerm_kubernetes_cluster.example.name}"
  description         = "Model tuning required when product count increases by 100."
  rule_group_enabled  = true
  interval            = "PT1M"
  scopes              = [azurerm_monitor_workspace.example.id]

  rule {
    alert      = "Product_Count_Increased_By_100"
    enabled    = true
    for        = "PT10M"
    expression = <<EOF
increase(total_product_count[8h]) > 100
EOF

    action {
      action_group_id = azurerm_monitor_action_group.email.id
    }

    action {
      action_group_id = azurerm_monitor_action_group.eventhub.id
    }

    alert_resolution {
      auto_resolved   = true
      time_to_resolve = "PT5M"
    }
  }
}
