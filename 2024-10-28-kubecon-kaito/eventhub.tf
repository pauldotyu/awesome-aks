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

# resource "azurerm_monitor_action_group" "example" {
#   name                = "ThumbsDownCountExceededAction"
#   resource_group_name = azurerm_resource_group.example.name
#   short_name          = "p0action"

#   event_hub_receiver {
#     event_hub_namespace     = azurerm_eventhub_namespace.example.name
#     event_hub_name          = azurerm_eventhub.example.name
#     name                    = "sendtoeventhub"
#     use_common_alert_schema = false
#   }
# }

# resource "azurerm_monitor_alert_prometheus_rule_group" "example" {
#   resource_group_name = azurerm_resource_group.example.name
#   location            = azurerm_resource_group.example.location
#   cluster_name        = azurerm_kubernetes_cluster.example.name
#   name                = "BigBerthaRecordingRulesRuleGroup - ${azurerm_kubernetes_cluster.example.name}"
#   description         = "Model retraining required when thumbs down count exceeds thumbs up count."
#   rule_group_enabled  = true
#   interval            = "PT1M"
#   scopes              = [azurerm_monitor_workspace.example.id]

#   rule {
#     alert      = "Thumbs_Down_Count_Exceeded"
#     enabled    = true
#     expression = <<EOF
# thumbs_down_count > thumbs_up_count
# EOF
#     for        = "PT1M"
#     severity   = 3

#     action {
#       action_group_id = azurerm_monitor_action_group.example.id
#     }

#     alert_resolution {
#       auto_resolved   = true
#       time_to_resolve = "PT5M"
#     }
#   }
# }
