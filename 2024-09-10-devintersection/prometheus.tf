resource "azurerm_monitor_workspace" "example" {
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  name                = "prom-${local.random_name}"
}

resource "azurerm_monitor_data_collection_endpoint" "msprom" {
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  name                = "MSProm-${azurerm_resource_group.example.location}-${azapi_resource.aks.name}"
  kind                = "Linux"
}


resource "azurerm_monitor_data_collection_rule" "msprom" {
  resource_group_name         = azurerm_resource_group.example.name
  location                    = azurerm_resource_group.example.location
  name                        = "MSProm-${azapi_resource.aks.location}-${azapi_resource.aks.name}"
  data_collection_endpoint_id = azurerm_monitor_data_collection_endpoint.msprom.id

  data_sources {
    prometheus_forwarder {
      name    = "PrometheusDataSource"
      streams = ["Microsoft-PrometheusMetrics"]
    }
  }

  destinations {
    monitor_account {
      monitor_account_id = azurerm_monitor_workspace.example.id
      name               = azurerm_monitor_workspace.example.name
    }
  }

  data_flow {
    streams      = ["Microsoft-PrometheusMetrics"]
    destinations = [azurerm_monitor_workspace.example.name]
  }
}

resource "azurerm_monitor_data_collection_rule_association" "dcr1" {
  target_resource_id      = azapi_resource.aks.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.msprom.id
  name                    = "dcr-${azapi_resource.aks.name}"
}

resource "azurerm_monitor_data_collection_rule_association" "dcr2" {
  target_resource_id          = azapi_resource.aks.id
  data_collection_endpoint_id = azurerm_monitor_data_collection_endpoint.msprom.id
}

resource "azurerm_monitor_alert_prometheus_rule_group" "node" {
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  cluster_name        = azapi_resource.aks.name
  name                = "NodeRecordingRulesRuleGroup - ${azapi_resource.aks.name}"
  rule_group_enabled  = true
  interval            = "PT1M"
  scopes              = [azurerm_monitor_workspace.example.id]

  rule {
    record     = "instance:node_num_cpu:sum"
    expression = "count without (cpu, mode) (node_cpu_seconds_total{job=\"node\",mode=\"idle\"})"
  }

  rule {
    record     = "instance:node_cpu_utilisation:rate5m"
    expression = "1 - avg without (cpu) (sum without (mode) (rate(node_cpu_seconds_total{job=\"node\", mode=~\"idle|iowait|steal\"}[5m])))"
  }

  rule {
    record     = "instance:node_load1_per_cpu:ratio"
    expression = "(node_load1{job=\"node\"}/  instance:node_num_cpu:sum{job=\"node\"})"
  }

  rule {
    record     = "instance:node_memory_utilisation:ratio"
    expression = "1 - ((node_memory_MemAvailable_bytes{job=\"node\"} or (node_memory_Buffers_bytes{job=\"node\"} + node_memory_Cached_bytes{job=\"node\"} + node_memory_MemFree_bytes{job=\"node\"} + node_memory_Slab_bytes{job=\"node\"})) / node_memory_MemTotal_bytes{job=\"node\"})"
  }

  rule {
    record     = "instance:node_vmstat_pgmajfault:rate5m"
    expression = "rate(node_vmstat_pgmajfault{job=\"node\"}[5m])"
  }

  rule {
    record     = "instance_device:node_disk_io_time_seconds:rate5m"
    expression = "rate(node_disk_io_time_seconds_total{job=\"node\", device!=\"\"}[5m])"
  }

  rule {
    record     = "instance_device:node_disk_io_time_weighted_seconds:rate5m"
    expression = "rate(node_disk_io_time_weighted_seconds_total{job=\"node\", device!=\"\"}[5m])"
  }

  rule {
    record     = "instance:node_network_receive_bytes_excluding_lo:rate5m"
    expression = "sum without (device) (rate(node_network_receive_bytes_total{job=\"node\", device!=\"lo\"}[5m]))"
  }

  rule {
    record     = "instance:node_network_transmit_bytes_excluding_lo:rate5m"
    expression = "sum without (device) (rate(node_network_transmit_bytes_total{job=\"node\", device!=\"lo\"}[5m]))"
  }

  rule {
    record     = "instance:node_network_receive_drop_excluding_lo:rate5m"
    expression = "sum without (device) (rate(node_network_receive_drop_total{job=\"node\", device!=\"lo\"}[5m]))"
  }

  rule {
    record     = "instance:node_network_transmit_drop_excluding_lo:rate5m"
    expression = "sum without (device) (rate(node_network_transmit_drop_total{job=\"node\", device!=\"lo\"}[5m]))"
  }
}

resource "azurerm_monitor_alert_prometheus_rule_group" "k8s" {
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  cluster_name        = azapi_resource.aks.name
  name                = "KubernetesRecordingRulesRuleGroup - ${azapi_resource.aks.name}"
  rule_group_enabled  = true
  interval            = "PT1M"
  scopes              = [azurerm_monitor_workspace.example.id]

  rule {
    record     = "node_namespace_pod_container:container_cpu_usage_seconds_total:sum_irate"
    expression = "sum by (cluster, namespace, pod, container) (irate(container_cpu_usage_seconds_total{job=\"cadvisor\", image!=\"\"}[5m])) * on (cluster, namespace, pod) group_left(node) topk by (cluster, namespace, pod) (1, max by(cluster, namespace, pod, node) (kube_pod_info{node!=\"\"}))"
  }

  rule {
    record     = "node_namespace_pod_container:container_memory_working_set_bytes"
    expression = "container_memory_working_set_bytes{job=\"cadvisor\", image!=\"\"}* on (namespace, pod) group_left(node) topk by(namespace, pod) (1, max by(namespace, pod, node) (kube_pod_info{node!=\"\"}))"
  }

  rule {
    record     = "node_namespace_pod_container:container_memory_rss"
    expression = "container_memory_rss{job=\"cadvisor\", image!=\"\"}* on (namespace, pod) group_left(node) topk by(namespace, pod) (1, max by(namespace, pod, node) (kube_pod_info{node!=\"\"}))"
  }

  rule {
    record     = "node_namespace_pod_container:container_memory_cache"
    expression = "container_memory_cache{job=\"cadvisor\", image!=\"\"}* on (namespace, pod) group_left(node) topk by(namespace, pod) (1, max by(namespace, pod, node) (kube_pod_info{node!=\"\"}))"
  }

  rule {
    record     = "node_namespace_pod_container:container_memory_swap"
    expression = "container_memory_swap{job=\"cadvisor\", image!=\"\"}* on (namespace, pod) group_left(node) topk by(namespace, pod) (1, max by(namespace, pod, node) (kube_pod_info{node!=\"\"}))"
  }

  rule {
    record     = "cluster:namespace:pod_memory:active:kube_pod_container_resource_requests"
    expression = "kube_pod_container_resource_requests{resource=\"memory\",job=\"kube-state-metrics\"} * on(namespace, pod, cluster)group_left() max by (namespace, pod, cluster) ((kube_pod_status_phase{phase=~\"Pending|Running\"} == 1))"
  }

  rule {
    record     = "namespace_memory:kube_pod_container_resource_requests:sum"
    expression = "sum by (namespace, cluster) (sum by (namespace, pod, cluster) (max by (namespace, pod, container, cluster) (kube_pod_container_resource_requests{resource=\"memory\",job=\"kube-state-metrics\"}) * on(namespace, pod, cluster) group_left() max by (namespace, pod, cluster) (kube_pod_status_phase{phase=~\"Pending|Running\"} == 1)))"
  }

  rule {
    record     = "cluster:namespace:pod_cpu:active:kube_pod_container_resource_requests"
    expression = "kube_pod_container_resource_requests{resource=\"cpu\",job=\"kube-state-metrics\"} * on (namespace, pod, cluster)group_left() max by (namespace, pod, cluster) ((kube_pod_status_phase{phase=~\"Pending|Running\"} == 1))"
  }

  rule {
    record     = "namespace_cpu:kube_pod_container_resource_requests:sum"
    expression = "sum by (namespace, cluster) (sum by(namespace, pod, cluster) (max by(namespace, pod, container, cluster) (kube_pod_container_resource_requests{resource=\"cpu\",job=\"kube-state-metrics\"}) * on(namespace, pod, cluster) group_left() max by (namespace, pod, cluster) (kube_pod_status_phase{phase=~\"Pending|Running\"} == 1)))"
  }

  rule {
    record     = "cluster:namespace:pod_memory:active:kube_pod_container_resource_limits"
    expression = "kube_pod_container_resource_limits{resource=\"memory\",job=\"kube-state-metrics\"} * on (namespace, pod, cluster)group_left() max by (namespace, pod, cluster) ((kube_pod_status_phase{phase=~\"Pending|Running\"} == 1))"
  }

  rule {
    record     = "namespace_memory:kube_pod_container_resource_limits:sum"
    expression = "sum by (namespace, cluster) (sum by (namespace, pod, cluster) (max by (namespace, pod, container, cluster) (kube_pod_container_resource_limits{resource=\"memory\",job=\"kube-state-metrics\"}) * on(namespace, pod, cluster) group_left() max by (namespace, pod, cluster) (kube_pod_status_phase{phase=~\"Pending|Running\"} == 1)))"
  }

  rule {
    record     = "cluster:namespace:pod_cpu:active:kube_pod_container_resource_limits"
    expression = "kube_pod_container_resource_limits{resource=\"cpu\",job=\"kube-state-metrics\"} * on (namespace, pod, cluster)group_left() max by (namespace, pod, cluster) ( (kube_pod_status_phase{phase=~\"Pending|Running\"} == 1) )"
  }

  rule {
    record     = "namespace_cpu:kube_pod_container_resource_limits:sum"
    expression = "sum by (namespace, cluster) (sum by (namespace, pod, cluster) (max by(namespace, pod, container, cluster) (kube_pod_container_resource_limits{resource=\"cpu\",job=\"kube-state-metrics\"}) * on(namespace, pod, cluster) group_left() max by (namespace, pod, cluster) (kube_pod_status_phase{phase=~\"Pending|Running\"} == 1)))"
  }

  rule {
    record     = "namespace_workload_pod:kube_pod_owner:relabel"
    expression = "max by (cluster, namespace, workload, pod) (label_replace(label_replace(kube_pod_owner{job=\"kube-state-metrics\", owner_kind=\"ReplicaSet\"}, \"replicaset\", \"$1\", \"owner_name\", \"(.*)\") * on(replicaset, namespace) group_left(owner_name) topk by(replicaset, namespace) (1, max by (replicaset, namespace, owner_name) (kube_replicaset_owner{job=\"kube-state-metrics\"})), \"workload\", \"$1\", \"owner_name\", \"(.*)\"))"
    labels = {
      "workload_type" = "deployment"
    }
  }

  rule {
    record     = "namespace_workload_pod:kube_pod_owner:relabel"
    expression = "max by (cluster, namespace, workload, pod) (label_replace(kube_pod_owner{job=\"kube-state-metrics\", owner_kind=\"DaemonSet\"}, \"workload\", \"$1\", \"owner_name\", \"(.*)\"))"
    labels = {
      "workload_type" = "daemonset"
    }
  }

  rule {
    record     = "namespace_workload_pod:kube_pod_owner:relabel"
    expression = "max by (cluster, namespace, workload, pod) (label_replace(kube_pod_owner{job=\"kube-state-metrics\", owner_kind=\"StatefulSet\"}, \"workload\", \"$1\", \"owner_name\", \"(.*)\"))"
    labels = {
      "workload_type" = "statefulset"
    }
  }

  rule {
    record     = "namespace_workload_pod:kube_pod_owner:relabel"
    expression = "max by (cluster, namespace, workload, pod) (label_replace(kube_pod_owner{job=\"kube-state-metrics\", owner_kind=\"Job\"}, \"workload\", \"$1\", \"owner_name\", \"(.*)\"))"
    labels = {
      "workload_type" = "job"
    }
  }

  rule {
    record     = ":node_memory_MemAvailable_bytes:sum"
    expression = "sum(node_memory_MemAvailable_bytes{job=\"node\"} or (node_memory_Buffers_bytes{job=\"node\"} + node_memory_Cached_bytes{job=\"node\"} + node_memory_MemFree_bytes{job=\"node\"} + node_memory_Slab_bytes{job=\"node\"})) by (cluster)"
  }

  rule {
    record     = "cluster:node_cpu:ratio_rate5m"
    expression = "sum(rate(node_cpu_seconds_total{job=\"node\",mode!=\"idle\",mode!=\"iowait\",mode!=\"steal\"}[5m])) by (cluster) /count(sum(node_cpu_seconds_total{job=\"node\"}) by (cluster, instance, cpu)) by (cluster)"
  }
}

resource "azurerm_monitor_data_collection_rule" "msci" {
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  name                = "MSCI-${azurerm_resource_group.example.location}-${azapi_resource.aks.name}"
  kind                = "Linux"

  data_sources {
    extension {
      name           = "ContainerInsightsExtension"
      extension_name = "ContainerInsights"
      streams        = ["Microsoft-ContainerInsights-Group-Default"]
      extension_json = <<JSON
      {
        "dataCollectionSettings": {
          "interval": "1m",
          "namespaceFilteringMode": "Off",
          "enableContainerLogV2": true
        }
      }
      JSON
    }
  }

  destinations {
    log_analytics {
      workspace_resource_id = azurerm_log_analytics_workspace.example.id
      name                  = azurerm_log_analytics_workspace.example.name
    }
  }

  data_flow {
    streams      = ["Microsoft-ContainerInsights-Group-Default"]
    destinations = [azurerm_log_analytics_workspace.example.name]
  }
}

resource "azurerm_monitor_data_collection_rule_association" "msci" {
  target_resource_id      = azapi_resource.aks.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.msci.id
  name                    = "msci-${azapi_resource.aks.name}"
}

# prometheus based container insights
resource "azurerm_monitor_alert_prometheus_rule_group" "ux" {
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  cluster_name        = azapi_resource.aks.name
  name                = "UXRecordingRulesRuleGroup - ${azapi_resource.aks.name}"
  description         = "UX Recording Rules for Linux"
  rule_group_enabled  = true
  interval            = "PT1M"
  scopes = [
    azurerm_monitor_workspace.example.id,
    azapi_resource.aks.id
  ]

  rule {
    record     = "ux:pod_cpu_usage:sum_irate"
    expression = "(sum by (namespace, pod, cluster, microsoft_resourceid) (\n\tirate(container_cpu_usage_seconds_total{container != \"\", pod != \"\", job = \"cadvisor\"}[5m])\n)) * on (pod, namespace, cluster, microsoft_resourceid) group_left (node, created_by_name, created_by_kind)\n(max by (node, created_by_name, created_by_kind, pod, namespace, cluster, microsoft_resourceid) (kube_pod_info{pod != \"\", job = \"kube-state-metrics\"}))"
  }

  rule {
    record     = "ux:controller_cpu_usage:sum_irate"
    expression = "sum by (namespace, node, cluster, created_by_name, created_by_kind, microsoft_resourceid) (\nux:pod_cpu_usage:sum_irate\n)\n"
  }

  rule {
    record     = "ux:pod_workingset_memory:sum"
    expression = "(\n\t    sum by (namespace, pod, cluster, microsoft_resourceid) (\n\t\tcontainer_memory_working_set_bytes{container != \"\", pod != \"\", job = \"cadvisor\"}\n\t    )\n\t) * on (pod, namespace, cluster, microsoft_resourceid) group_left (node, created_by_name, created_by_kind)\n(max by (node, created_by_name, created_by_kind, pod, namespace, cluster, microsoft_resourceid) (kube_pod_info{pod != \"\", job = \"kube-state-metrics\"}))"
  }

  rule {
    record     = "ux:controller_workingset_memory:sum"
    expression = "sum by (namespace, node, cluster, created_by_name, created_by_kind, microsoft_resourceid) (\nux:pod_workingset_memory:sum\n)"
  }

  rule {
    record     = "ux:pod_rss_memory:sum"
    expression = "(\n\t    sum by (namespace, pod, cluster, microsoft_resourceid) (\n\t\tcontainer_memory_rss{container != \"\", pod != \"\", job = \"cadvisor\"}\n\t    )\n\t) * on (pod, namespace, cluster, microsoft_resourceid) group_left (node, created_by_name, created_by_kind)\n(max by (node, created_by_name, created_by_kind, pod, namespace, cluster, microsoft_resourceid) (kube_pod_info{pod != \"\", job = \"kube-state-metrics\"}))"
  }

  rule {
    record     = "ux:controller_rss_memory:sum"
    expression = "sum by (namespace, node, cluster, created_by_name, created_by_kind, microsoft_resourceid) (\nux:pod_rss_memory:sum\n)"
  }

  rule {
    record     = "ux:pod_container_count:sum"
    expression = "sum by (node, created_by_name, created_by_kind, namespace, cluster, pod, microsoft_resourceid) (\n(\n(\nsum by (container, pod, namespace, cluster, microsoft_resourceid) (kube_pod_container_info{container != \"\", pod != \"\", container_id != \"\", job = \"kube-state-metrics\"})\nor sum by (container, pod, namespace, cluster, microsoft_resourceid) (kube_pod_init_container_info{container != \"\", pod != \"\", container_id != \"\", job = \"kube-state-metrics\"})\n)\n* on (pod, namespace, cluster, microsoft_resourceid) group_left (node, created_by_name, created_by_kind)\n(\nmax by (node, created_by_name, created_by_kind, pod, namespace, cluster, microsoft_resourceid) (\n\tkube_pod_info{pod != \"\", job = \"kube-state-metrics\"}\n)\n)\n)\n\n)"
  }

  rule {
    record     = "ux:controller_container_count:sum"
    expression = "sum by (node, created_by_name, created_by_kind, namespace, cluster, microsoft_resourceid) (\nux:pod_container_count:sum\n)"
  }

  rule {
    record     = "ux:pod_container_restarts:max"
    expression = "max by (node, created_by_name, created_by_kind, namespace, cluster, pod, microsoft_resourceid) (\n(\n(\nmax by (container, pod, namespace, cluster, microsoft_resourceid) (kube_pod_container_status_restarts_total{container != \"\", pod != \"\", job = \"kube-state-metrics\"})\nor sum by (container, pod, namespace, cluster, microsoft_resourceid) (kube_pod_init_status_restarts_total{container != \"\", pod != \"\", job = \"kube-state-metrics\"})\n)\n* on (pod, namespace, cluster, microsoft_resourceid) group_left (node, created_by_name, created_by_kind)\n(\nmax by (node, created_by_name, created_by_kind, pod, namespace, cluster, microsoft_resourceid) (\n\tkube_pod_info{pod != \"\", job = \"kube-state-metrics\"}\n)\n)\n)\n\n)"
  }

  rule {
    record     = "ux:controller_container_restarts:max"
    expression = "max by (node, created_by_name, created_by_kind, namespace, cluster, microsoft_resourceid) (\nux:pod_container_restarts:max\n)"
  }

  rule {
    record     = "ux:pod_resource_limit:sum"
    expression = "(sum by (cluster, pod, namespace, resource, microsoft_resourceid) (\n(\n\tmax by (cluster, microsoft_resourceid, pod, container, namespace, resource)\n\t (kube_pod_container_resource_limits{container != \"\", pod != \"\", job = \"kube-state-metrics\"})\n)\n)unless (count by (pod, namespace, cluster, resource, microsoft_resourceid)\n\t(kube_pod_container_resource_limits{container != \"\", pod != \"\", job = \"kube-state-metrics\"})\n!= on (pod, namespace, cluster, microsoft_resourceid) group_left()\n sum by (pod, namespace, cluster, microsoft_resourceid)\n (kube_pod_container_info{container != \"\", pod != \"\", job = \"kube-state-metrics\"}) \n)\n\n)* on (namespace, pod, cluster, microsoft_resourceid) group_left (node, created_by_kind, created_by_name)\n(\n\tkube_pod_info{pod != \"\", job = \"kube-state-metrics\"}\n)"
  }

  rule {
    record     = "ux:controller_resource_limit:sum"
    expression = "sum by (cluster, namespace, created_by_name, created_by_kind, node, resource, microsoft_resourceid) (\nux:pod_resource_limit:sum\n)"
  }

  rule {
    record     = "ux:controller_pod_phase_count:sum"
    expression = "sum by (cluster, phase, node, created_by_kind, created_by_name, namespace, microsoft_resourceid) ( (\n(kube_pod_status_phase{job=\"kube-state-metrics\",pod!=\"\"})\n or (label_replace((count(kube_pod_deletion_timestamp{job=\"kube-state-metrics\",pod!=\"\"}) by (namespace, pod, cluster, microsoft_resourceid) * count(kube_pod_status_reason{reason=\"NodeLost\", job=\"kube-state-metrics\"} == 0) by (namespace, pod, cluster, microsoft_resourceid)), \"phase\", \"terminating\", \"\", \"\"))) * on (pod, namespace, cluster, microsoft_resourceid) group_left (node, created_by_name, created_by_kind)\n(\nmax by (node, created_by_name, created_by_kind, pod, namespace, cluster, microsoft_resourceid) (\nkube_pod_info{job=\"kube-state-metrics\",pod!=\"\"}\n)\n)\n)"
  }

  rule {
    record     = "ux:cluster_pod_phase_count:sum"
    expression = "sum by (cluster, phase, node, namespace, microsoft_resourceid) (\nux:controller_pod_phase_count:sum\n)"
  }

  rule {
    record     = "ux:node_cpu_usage:sum_irate"
    expression = "sum by (instance, cluster, microsoft_resourceid) (\n(1 - irate(node_cpu_seconds_total{job=\"node\", mode=\"idle\"}[5m]))\n)"
  }

  rule {
    record     = "ux:node_memory_usage:sum"
    expression = "sum by (instance, cluster, microsoft_resourceid) ((\nnode_memory_MemTotal_bytes{job = \"node\"}\n- node_memory_MemFree_bytes{job = \"node\"} \n- node_memory_cached_bytes{job = \"node\"}\n- node_memory_buffers_bytes{job = \"node\"}\n))"
  }

  rule {
    record     = "ux:node_network_receive_drop_total:sum_irate"
    expression = "sum by (instance, cluster, microsoft_resourceid) (irate(node_network_receive_drop_total{job=\"node\", device!=\"lo\"}[5m]))"
  }

  rule {
    record     = "ux:node_network_transmit_drop_total:sum_irate"
    expression = "sum by (instance, cluster, microsoft_resourceid) (irate(node_network_transmit_drop_total{job=\"node\", device!=\"lo\"}[5m]))"
  }
}

resource "azurerm_monitor_alert_prometheus_rule_group" "uxw" {
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  cluster_name        = azapi_resource.aks.name
  name                = "UXRecordingRulesRuleGroup-Win - ${azapi_resource.aks.name}"
  description         = "UX Recording Rules for Windows"
  rule_group_enabled  = false
  interval            = "PT1M"
  scopes = [
    azurerm_monitor_workspace.example.id,
    azapi_resource.aks.id
  ]

  rule {
    record     = "ux:pod_cpu_usage_windows:sum_irate"
    expression = "sum by (cluster, pod, namespace, node, created_by_kind, created_by_name, microsoft_resourceid) (\n\t(\n\t\tmax by (instance, container_id, cluster, microsoft_resourceid) (\n\t\t\tirate(windows_container_cpu_usage_seconds_total{ container_id != \"\", job = \"windows-exporter\"}[5m])\n\t\t) * on (container_id, cluster, microsoft_resourceid) group_left (container, pod, namespace) (\n\t\t\tmax by (container, container_id, pod, namespace, cluster, microsoft_resourceid) (\n\t\t\t\tkube_pod_container_info{container != \"\", pod != \"\", container_id != \"\", job = \"kube-state-metrics\"}\n\t\t\t)\n\t\t)\n\t) * on (pod, namespace, cluster, microsoft_resourceid) group_left (node, created_by_name, created_by_kind)\n\t(\n\t\tmax by (node, created_by_name, created_by_kind, pod, namespace, cluster, microsoft_resourceid) (\n\t\t  kube_pod_info{ pod != \"\", job = \"kube-state-metrics\"}\n\t\t)\n\t)\n)"
  }

  rule {
    record     = "ux:controller_cpu_usage_windows:sum_irate"
    expression = "sum by (namespace, node, cluster, created_by_name, created_by_kind, microsoft_resourceid) (\nux:pod_cpu_usage_windows:sum_irate\n)\n"
  }

  rule {
    record     = "ux:pod_workingset_memory_windows:sum"
    expression = "sum by (cluster, pod, namespace, node, created_by_kind, created_by_name, microsoft_resourceid) (\n\t(\n\t\tmax by (instance, container_id, cluster, microsoft_resourceid) (\n\t\t\twindows_container_memory_usage_private_working_set_bytes{ container_id != \"\", job = \"windows-exporter\"}\n\t\t) * on (container_id, cluster, microsoft_resourceid) group_left (container, pod, namespace) (\n\t\t\tmax by (container, container_id, pod, namespace, cluster, microsoft_resourceid) (\n\t\t\t\tkube_pod_container_info{container != \"\", pod != \"\", container_id != \"\", job = \"kube-state-metrics\"}\n\t\t\t)\n\t\t)\n\t) * on (pod, namespace, cluster, microsoft_resourceid) group_left (node, created_by_name, created_by_kind)\n\t(\n\t\tmax by (node, created_by_name, created_by_kind, pod, namespace, cluster, microsoft_resourceid) (\n\t\t  kube_pod_info{ pod != \"\", job = \"kube-state-metrics\"}\n\t\t)\n\t)\n)"
  }

  rule {
    record     = "ux:controller_workingset_memory_windows:sum"
    expression = "sum by (namespace, node, cluster, created_by_name, created_by_kind, microsoft_resourceid) (\nux:pod_workingset_memory_windows:sum\n)"
  }

  rule {
    record     = "ux:node_cpu_usage_windows:sum_irate"
    expression = "sum by (instance, cluster, microsoft_resourceid) (\n(1 - irate(windows_cpu_time_total{job=\"windows-exporter\", mode=\"idle\"}[5m]))\n)"
  }

  rule {
    record     = "ux:node_memory_usage_windows:sum"
    expression = "sum by (instance, cluster, microsoft_resourceid) ((\nwindows_os_visible_memory_bytes{job = \"windows-exporter\"}\n- windows_memory_available_bytes{job = \"windows-exporter\"}\n))"
  }

  rule {
    record     = "ux:node_network_packets_received_drop_total_windows:sum_irate"
    expression = "sum by (instance, cluster, microsoft_resourceid) (irate(windows_net_packets_received_discarded_total{job=\"windows-exporter\", device!=\"lo\"}[5m]))"
  }

  rule {
    record     = "ux:node_network_packets_outbound_drop_total_windows:sum_irate"
    expression = "sum by (instance, cluster, microsoft_resourceid) (irate(windows_net_packets_outbound_discarded_total{job=\"windows-exporter\", device!=\"lo\"}[5m]))"
  }
}
