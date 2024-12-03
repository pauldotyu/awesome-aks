resource "local_file" "eventbus" {
  filename = "manifests/eventbus.yaml"
  content = templatefile("manifests/eventbus.tmpl",
    {
      NAMESPACE = kubernetes_namespace.example.metadata[0].name
    }
  )
}

resource "local_file" "eventsensor" {
  filename = "manifests/eventsensor.yaml"
  content = templatefile("manifests/eventsensor.tmpl",
    {
      NAMESPACE = kubernetes_namespace.example.metadata[0].name
    }
  )
}

resource "local_file" "eventsource" {
  filename = "manifests/eventsource.yaml"
  content = templatefile("manifests/eventsource.tmpl",
    {
      NAMESPACE     = kubernetes_namespace.example.metadata[0].name
      EVENTHUB_FQDN = "${azurerm_eventhub_namespace.example.name}.servicebus.windows.net"
      EVENTHUB_NAME = azurerm_eventhub.example.name
    }
  )
}

resource "local_file" "workflowauthz" {
  filename = "manifests/workflowauthz.yaml"
  content = templatefile("manifests/workflowauthz.tmpl",
    {
      NAMESPACE = kubernetes_namespace.example.metadata[0].name
    }
  )
}

resource "local_file" "workflowtemplate" {
  filename = "manifests/workflowtemplate.yaml"
  content = templatefile("manifests/workflowtemplate.tmpl",
    {
      NAMESPACE  = kubernetes_namespace.example.metadata[0].name
      REGISTRY   = azurerm_container_registry.example.login_server
      REPOSITORY = var.registry_repository_name
    }
  )
}

resource "local_file" "workflowuiauthz" {
  filename = "manifests/workflowuiauthz.yaml"
  content = templatefile("manifests/workflowuiauthz.tmpl",
    {
      NAMESPACE  = kubernetes_namespace.example.metadata[0].name
    }
  )
}
