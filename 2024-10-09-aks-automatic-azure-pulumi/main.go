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

func main() {
	pulumi.Run(func(ctx *pulumi.Context) error {
		// Create a random pet name to be used as a base for resource names
		randomPet, _ := random.NewRandomPet(ctx, "randomPet", &random.RandomPetArgs{
			Length:    pulumi.Int(2),
			Separator: pulumi.String(""),
		})

		// Create a 4 digit random integer to be used for resource names
		randomInt, _ := random.NewRandomInteger(ctx, "randomInt", &random.RandomIntegerArgs{
			Min: pulumi.Int(1000),
			Max: pulumi.Int(9999),
		})

		// Create a random name to be used for resource names
		randomName := pulumi.Sprintf("%v%v", randomPet.ID(), randomInt.Result)

		// Create an Azure Resource Group
		resourceGroup, err := resources.NewResourceGroup(ctx, "resourceGroup", &resources.ResourceGroupArgs{
			ResourceGroupName: pulumi.Sprintf("rg-%v", randomName),
		})
		if err != nil {
			return err
		}

		// Create Azure Container Registry
		containerRegistry, err := containerregistry.NewRegistry(ctx, "containerRegistry", &containerregistry.RegistryArgs{
			ResourceGroupName: resourceGroup.Name,
			RegistryName:      pulumi.Sprintf("acr%v", randomName),
			Sku: &containerregistry.SkuArgs{
				Name: pulumi.String("Standard"),
			},
		})
		if err != nil {
			return err
		}

		// Create Azure Log Analytics Workspace for Container Insights
		logAnalyticsWorkspace, err := operationalinsights.NewWorkspace(ctx, "logAnalyticsWorkspace", &operationalinsights.WorkspaceArgs{
			ResourceGroupName: resourceGroup.Name,
			WorkspaceName:     pulumi.Sprintf("logs-%v", randomName),
			Sku: &operationalinsights.WorkspaceSkuArgs{
				Name: pulumi.String("PerGB2018"),
			},
			RetentionInDays: pulumi.Int(30),
		})
		if err != nil {
			return err
		}

		// Create Azure Monitor Workspace for managed Prometheus
		azureMonitorWorkspace, err := monitor.NewAzureMonitorWorkspace(ctx, "azureMonitorWorkspace", &monitor.AzureMonitorWorkspaceArgs{
			ResourceGroupName:         resourceGroup.Name,
			AzureMonitorWorkspaceName: pulumi.Sprintf("prom-%v", randomName),
		})
		if err != nil {
			return err
		}

		// Create Azure Managed Grafana with Azure Monitor Workspace integration
		grafanaDashboard, err := dashboard.NewGrafana(ctx, "grafanaDashboard", &dashboard.GrafanaArgs{
			ResourceGroupName: resourceGroup.Name,
			WorkspaceName:     pulumi.Sprintf("graf-%v", randomName),
			Sku: &dashboard.ResourceSkuArgs{
				Name: pulumi.String("Standard"),
			},
			Identity: &dashboard.ManagedServiceIdentityArgs{
				Type: pulumi.String("SystemAssigned"),
			},
			Properties: dashboard.ManagedGrafanaPropertiesArgs{
				ApiKey:              pulumi.String("Enabled"),
				PublicNetworkAccess: pulumi.String("Enabled"),
				GrafanaIntegrations: dashboard.GrafanaIntegrationsArgs{
					AzureMonitorWorkspaceIntegrations: dashboard.AzureMonitorWorkspaceIntegrationArray{
						&dashboard.AzureMonitorWorkspaceIntegrationArgs{
							AzureMonitorWorkspaceResourceId: azureMonitorWorkspace.ID(),
						},
					},
				},
			},
		})
		if err != nil {
			return err
		}

		// Create AKS Automatic cluster
		managedCluster, err := containerservice.NewManagedCluster(ctx, "managedCluster", &containerservice.ManagedClusterArgs{
			ResourceGroupName: resourceGroup.Name,
			ResourceName:      pulumi.Sprintf("aks-%v", randomName),
			Sku: &containerservice.ManagedClusterSKUArgs{
				Name: pulumi.String("Automatic"),
				Tier: pulumi.String("Standard"),
			},
			AgentPoolProfiles: containerservice.ManagedClusterAgentPoolProfileArray{
				&containerservice.ManagedClusterAgentPoolProfileArgs{
					Mode:   pulumi.String("System"),
					Name:   pulumi.String("systempool"),
					VmSize: pulumi.String("Standard_DS4_v2"),
					Count:  pulumi.Int(3),
				},
			},
			AddonProfiles: containerservice.ManagedClusterAddonProfileMap{
				"omsagent": &containerservice.ManagedClusterAddonProfileArgs{
					Enabled: pulumi.Bool(true),
					Config: pulumi.StringMap{
						"logAnalyticsWorkspaceResourceID": logAnalyticsWorkspace.ID(),
						"useAADAuth":                      pulumi.String("true"),
					},
				},
			},
			AzureMonitorProfile: containerservice.ManagedClusterAzureMonitorProfileArgs{
				Metrics: containerservice.ManagedClusterAzureMonitorProfileMetricsArgs{
					Enabled: pulumi.Bool(true),
					KubeStateMetrics: containerservice.ManagedClusterAzureMonitorProfileKubeStateMetricsArgs{
						MetricAnnotationsAllowList: pulumi.String(""),
						MetricLabelsAllowlist:      pulumi.String(""),
					},
				},
			},
			Identity: &containerservice.ManagedClusterIdentityArgs{
				Type: containerservice.ResourceIdentityTypeSystemAssigned,
			},
		})
		if err != nil {
			return err
		}

		// Get the kubelet's principal ID for AcrPull role assignment
		kubeletPrincipalId := managedCluster.IdentityProfile.MapIndex(pulumi.String("kubeletidentity")).ObjectId()

		// Get current user principal
		client, err := authorization.GetClientConfig(ctx, pulumi.CompositeInvoke())
		if err != nil {
			return err
		}

		// Create a role assignment so I can access the kubeapiserver
		_, err = authorization.NewRoleAssignment(ctx, "managedClusterRoleAssignment", &authorization.RoleAssignmentArgs{
			PrincipalId:      pulumi.String(client.ObjectId),
			RoleDefinitionId: pulumi.String("/providers/Microsoft.Authorization/roleDefinitions/b1ff04bb-8a4e-4dc4-8eb5-8693973ce19b"),
			Scope:            managedCluster.ID(),
			PrincipalType:    pulumi.String("User"),
		})
		if err != nil {
			return err
		}

		// Create a role assignment so I can query the Azure Monitor Workspace
		_, err = authorization.NewRoleAssignment(ctx, "azureMonitorWorkspaceRoleAssignment2", &authorization.RoleAssignmentArgs{
			PrincipalId:      pulumi.String(client.ObjectId),
			RoleDefinitionId: pulumi.String("/providers/Microsoft.Authorization/roleDefinitions/43d0d8ad-25c7-4714-9337-8ba259a9fe05"),
			Scope:            azureMonitorWorkspace.ID(),
			PrincipalType:    pulumi.String("User"),
		})
		if err != nil {
			return err
		}

		// Create a role assignment so I can access Azure Managed Grafana dashboards
		_, err = authorization.NewRoleAssignment(ctx, "grafanaRoleAssignment", &authorization.RoleAssignmentArgs{
			PrincipalId:      pulumi.String(client.ObjectId),
			RoleDefinitionId: pulumi.String("/providers/Microsoft.Authorization/roleDefinitions/22926164-76b3-42b3-bc55-97df8dab3e41"),
			Scope:            grafanaDashboard.ID(),
			PrincipalType:    pulumi.String("User"),
		})
		if err != nil {
			return err
		}

		// Create a role assignment so that the kubelet can pull images from ACR
		_, err = authorization.NewRoleAssignment(ctx, "kubeletRoleAssignment", &authorization.RoleAssignmentArgs{
			PrincipalId:      kubeletPrincipalId.Elem().ToStringOutput(),
			RoleDefinitionId: pulumi.String("/providers/Microsoft.Authorization/roleDefinitions/7f951dda-4ed3-4680-a7ca-43fe172d538d"),
			Scope:            containerRegistry.ID(),
			PrincipalType:    pulumi.String("ServicePrincipal"),
		})
		if err != nil {
			return err
		}

		// Create a role assignment so that Azure Managed Grafana can query the Azure Monitor Workspace and Log Analytics Workspace
		_, err = authorization.NewRoleAssignment(ctx, "azureMonitorWorkspaceRoleAssignment1", &authorization.RoleAssignmentArgs{
			PrincipalId:      grafanaDashboard.Identity.Elem().PrincipalId(),
			RoleDefinitionId: pulumi.String("/providers/Microsoft.Authorization/roleDefinitions/43d0d8ad-25c7-4714-9337-8ba259a9fe05"),
			Scope:            resourceGroup.ID(),
			PrincipalType:    pulumi.String("ServicePrincipal"),
		})
		if err != nil {
			return err
		}

		// Create a data collection endpoint
		dataCollectionEndpoint, err := insights.NewDataCollectionEndpoint(ctx, "dataCollectionEndpoint", &insights.DataCollectionEndpointArgs{
			DataCollectionEndpointName: pulumi.Sprintf("MSProm-%v-%v", managedCluster.Location, managedCluster.Name),
			NetworkAcls: &insights.DataCollectionEndpointNetworkAclsArgs{
				PublicNetworkAccess: pulumi.String("Enabled"),
			},
			ResourceGroupName: resourceGroup.Name,
			Kind:              pulumi.String("Linux"),
		})
		if err != nil {
			return err
		}

		// Create a data collection rule for Container Insights
		msciDataCollectionRule, err := insights.NewDataCollectionRule(ctx, "msciDataCollectionRule", &insights.DataCollectionRuleArgs{
			DataCollectionRuleName:   pulumi.Sprintf("MSCI-%v-%v", managedCluster.Location, managedCluster.Name),
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
						WorkspaceResourceId: logAnalyticsWorkspace.ID(),
					},
				},
			},
			DataFlows: insights.DataFlowArray{
				insights.DataFlowArgs{
					Streams:      pulumi.ToStringArray([]string{"Microsoft-ContainerInsights-Group-Default"}),
					Destinations: pulumi.ToStringArray([]string{"ciworkspace"}),
				},
			},
			ResourceGroupName: resourceGroup.Name,
		})
		if err != nil {
			return err
		}

		// Link the Container Insights data collection rule to the AKS cluster
		_, err = insights.NewDataCollectionRuleAssociation(ctx, "msciDataCollectionRuleAssociation", &insights.DataCollectionRuleAssociationArgs{
			AssociationName:      pulumi.String("msciToAKS"),
			DataCollectionRuleId: msciDataCollectionRule.ID(),
			ResourceUri:          managedCluster.ID(),
		})
		if err != nil {
			return err
		}

		// Create a data collection rule for Prometheus metrics
		mspromDataCollectionRule, err := insights.NewDataCollectionRule(ctx, "mspromDataCollectionRule", &insights.DataCollectionRuleArgs{
			DataCollectionRuleName:   pulumi.Sprintf("MSProm-%v-%v", managedCluster.Location, managedCluster.Name),
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
						AccountResourceId: azureMonitorWorkspace.ID(),
					},
				},
			},
			DataFlows: insights.DataFlowArray{
				insights.DataFlowArgs{
					Streams:      pulumi.ToStringArray([]string{"Microsoft-PrometheusMetrics"}),
					Destinations: pulumi.ToStringArray([]string{"MonitoringAccount1"}),
				},
			},
			ResourceGroupName: resourceGroup.Name,
		})
		if err != nil {
			return err
		}

		// Link the Prometheus data collection rule to the AKS cluster
		_, err = insights.NewDataCollectionRuleAssociation(ctx, "mspromDataCollectionRuleAssociation", &insights.DataCollectionRuleAssociationArgs{
			AssociationName:      pulumi.String("mspromToAKS"),
			DataCollectionRuleId: mspromDataCollectionRule.ID(),
			ResourceUri:          managedCluster.ID(),
		})
		if err != nil {
			return err
		}

		// Create Prometheus rule group for K8s
		_, err = alertsmanagement.NewPrometheusRuleGroup(ctx, "k8sPrometheusRuleGroup", &alertsmanagement.PrometheusRuleGroupArgs{
			ResourceGroupName: resourceGroup.Name,
			RuleGroupName:     pulumi.Sprintf("KubernetesRecordingRulesRuleGroup - %v", managedCluster.Name),
			Interval:          pulumi.String("PT1M"),
			Description:       pulumi.String("Kubernetes Recording Rules RuleGroup"),
			ClusterName:       managedCluster.Name,
			Enabled:           pulumi.Bool(true),
			Scopes: pulumi.StringArray{
				azureMonitorWorkspace.ID(),
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
			ResourceGroupName: resourceGroup.Name,
			RuleGroupName:     pulumi.Sprintf("NodeRecordingRulesRuleGroup - %v", managedCluster.Name),
			Interval:          pulumi.String("PT1M"),
			Description:       pulumi.String("Node Recording Rules RuleGroup"),
			ClusterName:       managedCluster.Name,
			Enabled:           pulumi.Bool(true),
			Scopes: pulumi.StringArray{
				azureMonitorWorkspace.ID(),
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

		// Pulumi exports
		ctx.Export("resourceGroupName", pulumi.All(resourceGroup.Name).ApplyT(
			func(args []interface{}) string {
				return args[0].(string)
			}))

		ctx.Export("containerRegistry", pulumi.All(containerRegistry.Name).ApplyT(
			func(args []interface{}) string {
				return args[0].(string)
			}))

		ctx.Export("logAnalyticsWorkspace", pulumi.All(logAnalyticsWorkspace.Name).ApplyT(
			func(args []interface{}) string {
				return args[0].(string)
			}))

		ctx.Export("azureMonitorWorkspace", pulumi.All(azureMonitorWorkspace.Name).ApplyT(
			func(args []interface{}) string {
				return args[0].(string)
			}))

		ctx.Export("grafanaDashboard", pulumi.All(grafanaDashboard.Name).ApplyT(
			func(args []interface{}) string {
				return args[0].(string)
			}))

		ctx.Export("aksName", pulumi.All(managedCluster.Name).ApplyT(
			func(args []interface{}) string {
				return args[0].(string)
			}))

		return nil
	})
}
