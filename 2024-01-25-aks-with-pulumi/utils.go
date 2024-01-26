package main

import (
	"github.com/pulumi/pulumi-azure-native-sdk/alertsmanagement/v2"
	"github.com/pulumi/pulumi-azure-native-sdk/authorization/v2"
	"github.com/pulumi/pulumi-azure-native-sdk/containerregistry/v2"
	"github.com/pulumi/pulumi-azure-native-sdk/containerservice/v2"
	"github.com/pulumi/pulumi-azure-native-sdk/dashboard/v2"
	"github.com/pulumi/pulumi-azure-native-sdk/insights/v2"
	"github.com/pulumi/pulumi-azure-native-sdk/monitor"
	"github.com/pulumi/pulumi-azure-native-sdk/operationalinsights/v2"
	"github.com/pulumi/pulumi-azure-native-sdk/resources/v2"
	"github.com/pulumi/pulumi-random/sdk/v4/go/random"
	"github.com/pulumi/pulumi/sdk/v3/go/pulumi"
)

type deploymentTypes struct {
	resourceGroup         *resources.ResourceGroup
	containerRegistry     *containerregistry.Registry
	logAnalyticsWorkspace *operationalinsights.Workspace
	azureMonitorWorkspace *monitor.AzureMonitorWorkspace
	grafanaDashboard      *dashboard.Grafana
	managedCluster        *containerservice.ManagedCluster
}

func newRandomName(ctx *pulumi.Context) (pulumi.StringOutput, error) {
	randomPet, err := random.NewRandomPet(ctx, "randomPet", &random.RandomPetArgs{
		Length:    pulumi.Int(2),
		Separator: pulumi.String(""),
	})
	if err != nil {
		return pulumi.StringOutput{}, err
	}

	randomInt, _ := random.NewRandomInteger(ctx, "randomInt", &random.RandomIntegerArgs{
		Min: pulumi.Int(10),
		Max: pulumi.Int(99),
	})
	if err != nil {
		return pulumi.StringOutput{}, err
	}

	return pulumi.Sprintf("%v%v", randomPet.ID(), randomInt.Result), nil
}

func assignRoles(ctx *pulumi.Context, d deploymentTypes) error {
	// Get the kubelet's principal ID for AcrPull role assignment
	kubeletPrincipalId := d.managedCluster.IdentityProfile.MapIndex(pulumi.String("kubeletidentity")).ObjectId()

	// Create a role assignment so that the kubelet can pull images from ACR
	_, err := authorization.NewRoleAssignment(ctx, "kubeletRoleAssignment", &authorization.RoleAssignmentArgs{
		PrincipalId:      kubeletPrincipalId.Elem().ToStringOutput(),
		RoleDefinitionId: acrPullRoleId,
		Scope:            d.containerRegistry.ID(),
		PrincipalType:    pulumi.String("ServicePrincipal"),
	})
	if err != nil {
		return err
	}

	// Create a role assignment so that Azure Managed Grafana can query the Azure Monitor Workspace and Log Analytics Workspace
	_, err = authorization.NewRoleAssignment(ctx, "azureMonitorWorkspaceRoleAssignment1", &authorization.RoleAssignmentArgs{
		PrincipalId:      d.grafanaDashboard.Identity.Elem().PrincipalId(),
		RoleDefinitionId: monitorReaderRoleID,
		Scope:            d.resourceGroup.ID(),
		PrincipalType:    pulumi.String("ServicePrincipal"),
	})
	if err != nil {
		return err
	}

	// Get current user principal
	client, err := authorization.GetClientConfig(ctx, pulumi.CompositeInvoke())
	if err != nil {
		return err
	}

	// Create a role assignment so I can query the Azure Monitor Workspace
	_, err = authorization.NewRoleAssignment(ctx, "azureMonitorWorkspaceRoleAssignment2", &authorization.RoleAssignmentArgs{
		PrincipalId:      pulumi.String(client.ObjectId),
		RoleDefinitionId: monitorReaderRoleID,
		Scope:            d.azureMonitorWorkspace.ID(),
		PrincipalType:    pulumi.String("User"),
	})
	if err != nil {
		return err
	}

	// Create a role assignment so I can access Azure Managed Grafana dashboards
	_, err = authorization.NewRoleAssignment(ctx, "grafanaRoleAssignment", &authorization.RoleAssignmentArgs{
		PrincipalId:      pulumi.String(client.ObjectId),
		RoleDefinitionId: grafanaAdminRoleID,
		Scope:            d.grafanaDashboard.ID(),
		PrincipalType:    pulumi.String("User"),
	})
	if err != nil {
		return err
	}

	return nil
}

func onboardInsights(ctx *pulumi.Context, d deploymentTypes) error {
	// Create a data collection endpoint
	dataCollectionEndpoint, err := insights.NewDataCollectionEndpoint(ctx, "dataCollectionEndpoint", &insights.DataCollectionEndpointArgs{
		DataCollectionEndpointName: pulumi.Sprintf("MSProm-%v-%v", d.managedCluster.Location, d.managedCluster.Name),
		NetworkAcls: &insights.DataCollectionEndpointNetworkAclsArgs{
			PublicNetworkAccess: pulumi.String("Enabled"),
		},
		ResourceGroupName: d.resourceGroup.Name,
		Kind:              pulumi.String("Linux"),
	})
	if err != nil {
		return err
	}

	// Create a data collection rule for Container Insights
	msciDataCollectionRule, err := insights.NewDataCollectionRule(ctx, "msciDataCollectionRule", &insights.DataCollectionRuleArgs{
		DataCollectionRuleName:   pulumi.Sprintf("MSCI-%v-%v", d.managedCluster.Location, d.managedCluster.Name),
		DataCollectionEndpointId: dataCollectionEndpoint.ID(),
		DataSources: insights.DataCollectionRuleDataSourcesArgs{
			Extensions: insights.ExtensionDataSourceArray{
				insights.ExtensionDataSourceArgs{
					Name:          pulumi.String("ContainerInsightsExtension"),
					Streams:       pulumi.ToStringArray([]string{"Microsoft-ContainerInsights-Group-Default"}),
					ExtensionName: pulumi.String("ContainerInsights"),
					ExtensionSettings: pulumi.Map{
						"dataCollectionSettings": pulumi.Map{
							"interval":               pulumi.String("1m"),
							"namespaceFilteringMode": pulumi.String("Off"),
							"enableContainerLogV2":   pulumi.Bool(true),
						},
					},
				},
			},
		},
		Destinations: insights.DataCollectionRuleDestinationsArgs{
			LogAnalytics: insights.LogAnalyticsDestinationArray{
				insights.LogAnalyticsDestinationArgs{
					Name:                pulumi.String("ciworkspace"),
					WorkspaceResourceId: d.logAnalyticsWorkspace.ID(),
				},
			},
		},
		DataFlows: insights.DataFlowArray{
			insights.DataFlowArgs{
				Streams:      pulumi.ToStringArray([]string{"Microsoft-ContainerInsights-Group-Default"}),
				Destinations: pulumi.ToStringArray([]string{"ciworkspace"}),
			},
		},
		ResourceGroupName: d.resourceGroup.Name,
	})
	if err != nil {
		return err
	}

	// Link the Container Insights data collection rule to the AKS cluster
	_, err = insights.NewDataCollectionRuleAssociation(ctx, "msciDataCollectionRuleAssociation", &insights.DataCollectionRuleAssociationArgs{
		AssociationName:      pulumi.String("msciToAKS"),
		DataCollectionRuleId: msciDataCollectionRule.ID(),
		ResourceUri:          d.managedCluster.ID(),
	})
	if err != nil {
		return err
	}

	// Create a data collection rule for Prometheus metrics
	mspromDataCollectionRule, err := insights.NewDataCollectionRule(ctx, "mspromDataCollectionRule", &insights.DataCollectionRuleArgs{
		DataCollectionRuleName:   pulumi.Sprintf("MSProm-%v-%v", d.managedCluster.Location, d.managedCluster.Name),
		DataCollectionEndpointId: dataCollectionEndpoint.ID(),
		DataSources: insights.DataCollectionRuleDataSourcesArgs{
			PrometheusForwarder: insights.PrometheusForwarderDataSourceArray{
				insights.PrometheusForwarderDataSourceArgs{
					Name:    pulumi.String("PrometheusDataSource"),
					Streams: pulumi.ToStringArray([]string{"Microsoft-PrometheusMetrics"}),
				},
			},
		},
		Destinations: insights.DataCollectionRuleDestinationsArgs{
			MonitoringAccounts: insights.MonitoringAccountDestinationArray{
				insights.MonitoringAccountDestinationArgs{
					Name:              pulumi.String("MonitoringAccount1"),
					AccountResourceId: d.azureMonitorWorkspace.ID(),
				},
			},
		},
		DataFlows: insights.DataFlowArray{
			insights.DataFlowArgs{
				Streams:      pulumi.ToStringArray([]string{"Microsoft-PrometheusMetrics"}),
				Destinations: pulumi.ToStringArray([]string{"MonitoringAccount1"}),
			},
		},
		ResourceGroupName: d.resourceGroup.Name,
	})
	if err != nil {
		return err
	}

	// Link the Prometheus data collection rule to the AKS cluster
	_, err = insights.NewDataCollectionRuleAssociation(ctx, "mspromDataCollectionRuleAssociation", &insights.DataCollectionRuleAssociationArgs{
		AssociationName:      pulumi.String("mspromToAKS"),
		DataCollectionRuleId: mspromDataCollectionRule.ID(),
		ResourceUri:          d.managedCluster.ID(),
	})
	if err != nil {
		return err
	}

	// Create Prometheus rule group for K8s
	_, err = alertsmanagement.NewPrometheusRuleGroup(ctx, "k8sPrometheusRuleGroup", &alertsmanagement.PrometheusRuleGroupArgs{
		ResourceGroupName: d.resourceGroup.Name,
		RuleGroupName:     pulumi.Sprintf("KubernetesRecordingRulesRuleGroup - %v", d.managedCluster.Name),
		Interval:          pulumi.String("PT1M"),
		Description:       pulumi.String("Kubernetes Recording Rules RuleGroup"),
		ClusterName:       d.managedCluster.Name,
		Enabled:           pulumi.Bool(true),
		Scopes: pulumi.StringArray{
			d.azureMonitorWorkspace.ID(),
		},
		Rules: alertsmanagement.PrometheusRuleArray{
			alertsmanagement.PrometheusRuleArgs{
				Record:     pulumi.String("node_namespace_pod_container:container_cpu_usage_seconds_total:sum_irate"),
				Expression: pulumi.String("sum by (cluster, namespace, pod, container) (irate(container_cpu_usage_seconds_total{job=\"cadvisor\", image!=\"\"}[5m])) * on (cluster, namespace, pod) group_left(node) topk by (cluster, namespace, pod) (1, max by(cluster, namespace, pod, node) (kube_pod_info{node!=\"\"}))"),
			},
			alertsmanagement.PrometheusRuleArgs{
				Record:     pulumi.String("node_namespace_pod_container:container_memory_working_set_bytes"),
				Expression: pulumi.String("container_memory_working_set_bytes{job=\"cadvisor\", image!=\"\"}* on (namespace, pod) group_left(node) topk by(namespace, pod) (1, max by(namespace, pod, node) (kube_pod_info{node!=\"\"}))"),
			},
			alertsmanagement.PrometheusRuleArgs{
				Record:     pulumi.String("node_namespace_pod_container:container_memory_rss"),
				Expression: pulumi.String("container_memory_rss{job=\"cadvisor\", image!=\"\"}* on (namespace, pod) group_left(node) topk by(namespace, pod) (1, max by(namespace, pod, node) (kube_pod_info{node!=\"\"}))"),
			},
			alertsmanagement.PrometheusRuleArgs{
				Record:     pulumi.String("node_namespace_pod_container:container_memory_cache"),
				Expression: pulumi.String("container_memory_cache{job=\"cadvisor\", image!=\"\"}* on (namespace, pod) group_left(node) topk by(namespace, pod) (1, max by(namespace, pod, node) (kube_pod_info{node!=\"\"}))"),
			},
			alertsmanagement.PrometheusRuleArgs{
				Record:     pulumi.String("node_namespace_pod_container:container_memory_swap"),
				Expression: pulumi.String("container_memory_swap{job=\"cadvisor\", image!=\"\"}* on (namespace, pod) group_left(node) topk by(namespace, pod) (1, max by(namespace, pod, node) (kube_pod_info{node!=\"\"}))"),
			},
			alertsmanagement.PrometheusRuleArgs{
				Record:     pulumi.String("cluster:namespace:pod_memory:active:kube_pod_container_resource_requests"),
				Expression: pulumi.String("kube_pod_container_resource_requests{resource=\"memory\",job=\"kube-state-metrics\"}  * on (namespace, pod, cluster)group_left() max by (namespace, pod, cluster) ((kube_pod_status_phase{phase=~\"Pending|Running\"} == 1))"),
			},
			alertsmanagement.PrometheusRuleArgs{
				Record:     pulumi.String("namespace_memory:kube_pod_container_resource_requests:sum"),
				Expression: pulumi.String("sum by (namespace, cluster) (sum by (namespace, pod, cluster) (max by (namespace, pod, container, cluster) (kube_pod_container_resource_requests{resource=\"memory\",job=\"kube-state-metrics\"}) * on(namespace, pod, cluster) group_left() max by (namespace, pod, cluster) (kube_pod_status_phase{phase=~\"Pending|Running\"} == 1)))"),
			},
			alertsmanagement.PrometheusRuleArgs{
				Record:     pulumi.String("cluster:namespace:pod_cpu:active:kube_pod_container_resource_requests"),
				Expression: pulumi.String("kube_pod_container_resource_requests{resource=\"cpu\",job=\"kube-state-metrics\"}  * on (namespace, pod, cluster)group_left() max by (namespace, pod, cluster) ((kube_pod_status_phase{phase=~\"Pending|Running\"} == 1))"),
			},
			alertsmanagement.PrometheusRuleArgs{
				Record:     pulumi.String("namespace_cpu:kube_pod_container_resource_requests:sum"),
				Expression: pulumi.String("sum by (namespace, cluster) (sum by (namespace, pod, cluster) (max by (namespace, pod, container, cluster) (kube_pod_container_resource_requests{resource=\"cpu\",job=\"kube-state-metrics\"}) * on(namespace, pod, cluster) group_left() max by (namespace, pod, cluster) (kube_pod_status_phase{phase=~\"Pending|Running\"} == 1)))"),
			},
			alertsmanagement.PrometheusRuleArgs{
				Record:     pulumi.String("cluster:namespace:pod_memory:active:kube_pod_container_resource_limits"),
				Expression: pulumi.String("kube_pod_container_resource_limits{resource=\"memory\",job=\"kube-state-metrics\"}  * on (namespace, pod, cluster)group_left() max by (namespace, pod, cluster) ((kube_pod_status_phase{phase=~\"Pending|Running\"} == 1))"),
			},
			alertsmanagement.PrometheusRuleArgs{
				Record:     pulumi.String("namespace_memory:kube_pod_container_resource_limits:sum"),
				Expression: pulumi.String("sum by (namespace, cluster) (sum by (namespace, pod, cluster) (max by (namespace, pod, container, cluster) (kube_pod_container_resource_limits{resource=\"memory\",job=\"kube-state-metrics\"}) * on(namespace, pod, cluster) group_left() max by (namespace, pod, cluster) (kube_pod_status_phase{phase=~\"Pending|Running\"} == 1)))"),
			},
			alertsmanagement.PrometheusRuleArgs{
				Record:     pulumi.String("cluster:namespace:pod_cpu:active:kube_pod_container_resource_limits"),
				Expression: pulumi.String("kube_pod_container_resource_limits{resource=\"cpu\",job=\"kube-state-metrics\"}  * on (namespace, pod, cluster)group_left() max by (namespace, pod, cluster) ( (kube_pod_status_phase{phase=~\"Pending|Running\"} == 1) )"),
			},
			alertsmanagement.PrometheusRuleArgs{
				Record:     pulumi.String("namespace_cpu:kube_pod_container_resource_limits:sum"),
				Expression: pulumi.String("sum by (namespace, cluster) (sum by (namespace, pod, cluster) (max by (namespace, pod, container, cluster) (kube_pod_container_resource_limits{resource=\"cpu\",job=\"kube-state-metrics\"}) * on(namespace, pod, cluster) group_left() max by (namespace, pod, cluster) (kube_pod_status_phase{phase=~\"Pending|Running\"} == 1)))"),
			},
			alertsmanagement.PrometheusRuleArgs{
				Record:     pulumi.String("namespace_workload_pod:kube_pod_owner:relabel"),
				Expression: pulumi.String("max by (cluster, namespace, workload, pod) (label_replace(label_replace(kube_pod_owner{job=\"kube-state-metrics\", owner_kind=\"ReplicaSet\"}, \"replicaset\", \"$1\", \"owner_name\", \"(.*)\") * on(replicaset, namespace) group_left(owner_name) topk by(replicaset, namespace) (1, max by (replicaset, namespace, owner_name) (kube_replicaset_owner{job=\"kube-state-metrics\"})), \"workload\", \"$1\", \"owner_name\", \"(.*)\"))"),
				Labels: pulumi.StringMap{
					"workload_type": pulumi.String("deployment"),
				},
			},
			alertsmanagement.PrometheusRuleArgs{
				Record:     pulumi.String("namespace_workload_pod:kube_pod_owner:relabel"),
				Expression: pulumi.String("max by (cluster, namespace, workload, pod) (label_replace(kube_pod_owner{job=\"kube-state-metrics\", owner_kind=\"DaemonSet\"}, \"workload\", \"$1\", \"owner_name\", \"(.*)\"))"),
				Labels: pulumi.StringMap{
					"workload_type": pulumi.String("daemonset"),
				},
			},
			alertsmanagement.PrometheusRuleArgs{
				Record:     pulumi.String("namespace_workload_pod:kube_pod_owner:relabel"),
				Expression: pulumi.String("max by (cluster, namespace, workload, pod) (label_replace(kube_pod_owner{job=\"kube-state-metrics\", owner_kind=\"StatefulSet\"}, \"workload\", \"$1\", \"owner_name\", \"(.*)\"))"),
				Labels: pulumi.StringMap{
					"workload_type": pulumi.String("statefulset"),
				},
			},
			alertsmanagement.PrometheusRuleArgs{
				Record:     pulumi.String("namespace_workload_pod:kube_pod_owner:relabel"),
				Expression: pulumi.String("max by (cluster, namespace, workload, pod) (label_replace(kube_pod_owner{job=\"kube-state-metrics\", owner_kind=\"Job\"}, \"workload\", \"$1\", \"owner_name\", \"(.*)\"))"),
				Labels: pulumi.StringMap{
					"workload_type": pulumi.String("job"),
				},
			},
			alertsmanagement.PrometheusRuleArgs{
				Record:     pulumi.String(":node_memory_MemAvailable_bytes:sum"),
				Expression: pulumi.String("sum(node_memory_MemAvailable_bytes{job=\"node\"} or  (node_memory_Buffers_bytes{job=\"node\"} +    node_memory_Cached_bytes{job=\"node\"} +    node_memory_MemFree_bytes{job=\"node\"} +    node_memory_Slab_bytes{job=\"node\"})) by (cluster)"),
			},
			alertsmanagement.PrometheusRuleArgs{
				Record:     pulumi.String("cluster:node_cpu:ratio_rate5m"),
				Expression: pulumi.String("sum(rate(node_cpu_seconds_total{job=\"node\",mode!=\"idle\",mode!=\"iowait\",mode!=\"steal\"}[5m])) by (cluster) /count(sum(node_cpu_seconds_total{job=\"node\"}) by (cluster, instance, cpu)) by (cluster)"),
			},
		},
	})
	if err != nil {
		return err
	}

	// Create Prometheus rule group for nodes
	_, err = alertsmanagement.NewPrometheusRuleGroup(ctx, "nodePrometheusRuleGroup", &alertsmanagement.PrometheusRuleGroupArgs{
		ResourceGroupName: d.resourceGroup.Name,
		RuleGroupName:     pulumi.Sprintf("NodeRecordingRulesRuleGroup - %v", d.managedCluster.Name),
		Interval:          pulumi.String("PT1M"),
		Description:       pulumi.String("Node Recording Rules RuleGroup"),
		ClusterName:       d.managedCluster.Name,
		Enabled:           pulumi.Bool(true),
		Scopes: pulumi.StringArray{
			d.azureMonitorWorkspace.ID(),
		},
		Rules: alertsmanagement.PrometheusRuleArray{
			alertsmanagement.PrometheusRuleArgs{
				Record:     pulumi.String("instance:node_num_cpu:sum"),
				Expression: pulumi.String("count without (cpu, mode) (node_cpu_seconds_total{job=\"node\",mode=\"idle\"})"),
			},
			alertsmanagement.PrometheusRuleArgs{
				Record:     pulumi.String("instance:node_cpu_utilisation:rate5m"),
				Expression: pulumi.String("1 - avg without (cpu) (sum without (mode) (rate(node_cpu_seconds_total{job=\"node\", mode=~\"idle|iowait|steal\"}[5m])))"),
			},
			alertsmanagement.PrometheusRuleArgs{
				Record:     pulumi.String("instance:node_load1_per_cpu:ratio"),
				Expression: pulumi.String("(node_load1{job=\"node\"}/  instance:node_num_cpu:sum{job=\"node\"})"),
			},
			alertsmanagement.PrometheusRuleArgs{
				Record:     pulumi.String("instance:node_memory_utilisation:ratio"),
				Expression: pulumi.String("1 - ((node_memory_MemAvailable_bytes{job=\"node\"} or (node_memory_Buffers_bytes{job=\"node\"} + node_memory_Cached_bytes{job=\"node\"} + node_memory_MemFree_bytes{job=\"node\"} + node_memory_Slab_bytes{job=\"node\"}))/  node_memory_MemTotal_bytes{job=\"node\"})"),
			},
			alertsmanagement.PrometheusRuleArgs{
				Record:     pulumi.String("instance:node_vmstat_pgmajfault:rate5m"),
				Expression: pulumi.String("rate(node_vmstat_pgmajfault{job=\"node\"}[5m])"),
			},
			alertsmanagement.PrometheusRuleArgs{
				Record:     pulumi.String("instance_device:node_disk_io_time_seconds:rate5m"),
				Expression: pulumi.String("rate(node_disk_io_time_seconds_total{job=\"node\", device!=\"\"}[5m])"),
			},
			alertsmanagement.PrometheusRuleArgs{
				Record:     pulumi.String("instance_device:node_disk_io_time_weighted_seconds:rate5m"),
				Expression: pulumi.String("rate(node_disk_io_time_weighted_seconds_total{job=\"node\", device!=\"\"}[5m])"),
			},
			alertsmanagement.PrometheusRuleArgs{
				Record:     pulumi.String("instance:node_network_receive_bytes_excluding_lo:rate5m"),
				Expression: pulumi.String("sum without (device) (rate(node_network_receive_bytes_total{job=\"node\", device!=\"lo\"}[5m]))"),
			},
			alertsmanagement.PrometheusRuleArgs{
				Record:     pulumi.String("instance:node_network_transmit_bytes_excluding_lo:rate5m"),
				Expression: pulumi.String("sum without (device) (rate(node_network_transmit_bytes_total{job=\"node\", device!=\"lo\"}[5m]))"),
			},
			alertsmanagement.PrometheusRuleArgs{
				Record:     pulumi.String("instance:node_network_receive_drop_excluding_lo:rate5m"),
				Expression: pulumi.String("sum without (device) (rate(node_network_receive_drop_total{job=\"node\", device!=\"lo\"}[5m]))"),
			},
			alertsmanagement.PrometheusRuleArgs{
				Record:     pulumi.String("instance:node_network_transmit_drop_excluding_lo:rate5m"),
				Expression: pulumi.String("sum without (device) (rate(node_network_transmit_drop_total{job=\"node\", device!=\"lo\"}[5m]))"),
			},
		},
	})
	if err != nil {
		return err
	}
	return nil
}
