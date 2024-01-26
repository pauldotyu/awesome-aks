package main

import (
	"github.com/pulumi/pulumi-azure-native-sdk/containerregistry/v2"
	"github.com/pulumi/pulumi-azure-native-sdk/containerservice/v2"
	"github.com/pulumi/pulumi-azure-native-sdk/dashboard/v2"
	"github.com/pulumi/pulumi-azure-native-sdk/monitor"
	"github.com/pulumi/pulumi-azure-native-sdk/operationalinsights/v2"
	"github.com/pulumi/pulumi-azure-native-sdk/resources/v2"
	"github.com/pulumi/pulumi/sdk/v3/go/pulumi"
)

const (
	aksNodeCount        = pulumi.Int(3)
	aksNodeVMSize       = pulumi.String("standard_d2_v4")
	aksNodeName         = pulumi.String("nodepool1")
	aksNodeMode         = pulumi.String("System")
	aksNetworkPlugin    = pulumi.String("kubenet")
	acrSku              = pulumi.String("Basic")
	acrPullRoleId       = pulumi.String("/providers/Microsoft.Authorization/roleDefinitions/7f951dda-4ed3-4680-a7ca-43fe172d538d")
	monitorReaderRoleID = pulumi.String("/providers/Microsoft.Authorization/roleDefinitions/43d0d8ad-25c7-4714-9337-8ba259a9fe05")
	grafanaAdminRoleID  = pulumi.String("/providers/Microsoft.Authorization/roleDefinitions/22926164-76b3-42b3-bc55-97df8dab3e41")
)

func main() {
	pulumi.Run(func(ctx *pulumi.Context) error {
		// Create a random petname to be used for resource names
		randomPet, err := newRandomName(ctx)
		if err != nil {
			return err
		}

		// Create Azure Resource Group
		resourceGroup, err := resources.NewResourceGroup(ctx, "resourceGroup", &resources.ResourceGroupArgs{
			ResourceGroupName: pulumi.Sprintf("rg-%v", randomPet),
		})
		if err != nil {
			return err
		}

		// Create Azure Container Registry
		containerRegistry, err := containerregistry.NewRegistry(ctx, "containerRegistry", &containerregistry.RegistryArgs{
			ResourceGroupName: resourceGroup.Name,
			RegistryName:      pulumi.Sprintf("acr%v", randomPet),
			Sku: &containerregistry.SkuArgs{
				Name: acrSku,
			},
		})
		if err != nil {
			return err
		}

		// Create Azure Log Analytics Workspace for Container Insights
		logAnalyticsWorkspace, err := operationalinsights.NewWorkspace(ctx, "logAnalyticsWorkspace", &operationalinsights.WorkspaceArgs{
			ResourceGroupName: resourceGroup.Name,
			RetentionInDays:   pulumi.Int(30),
			Sku: &operationalinsights.WorkspaceSkuArgs{
				Name: pulumi.String("PerGB2018"),
			},
			WorkspaceName: pulumi.Sprintf("law-%v", randomPet),
		})
		if err != nil {
			return err
		}

		// Create Azure Monitor Workspace for managed Prometheus
		azureMonitorWorkspace, err := monitor.NewAzureMonitorWorkspace(ctx, "azureMonitorWorkspace", &monitor.AzureMonitorWorkspaceArgs{
			AzureMonitorWorkspaceName: pulumi.Sprintf("amon-%v", randomPet),
			ResourceGroupName:         resourceGroup.Name,
		})
		if err != nil {
			return err
		}

		// Create Azure Managed Grafana with Azure Monitor Workspace integration
		grafanaDashboard, err := dashboard.NewGrafana(ctx, "grafanaDashboard", &dashboard.GrafanaArgs{
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
			ResourceGroupName: resourceGroup.Name,
			Sku: &dashboard.ResourceSkuArgs{
				Name: pulumi.String("Standard"),
			},
			WorkspaceName: pulumi.Sprintf("amg-%v", randomPet),
		})
		if err != nil {
			return err
		}

		// Create Azure Kubernetes Service cluster
		managedCluster, err := containerservice.NewManagedCluster(ctx, "managedCluster", &containerservice.ManagedClusterArgs{
			ResourceGroupName: resourceGroup.Name,
			AddonProfiles: containerservice.ManagedClusterAddonProfileMap{
				"omsagent": &containerservice.ManagedClusterAddonProfileArgs{
					Enabled: pulumi.Bool(true),
					Config: pulumi.StringMap{
						"logAnalyticsWorkspaceResourceID": logAnalyticsWorkspace.ID(),
						"useAADAuth":                      pulumi.String("true"),
					},
				},
			},
			AgentPoolProfiles: containerservice.ManagedClusterAgentPoolProfileArray{
				&containerservice.ManagedClusterAgentPoolProfileArgs{
					Mode:   aksNodeMode,
					Name:   aksNodeName,
					VmSize: aksNodeVMSize,
					Count:  aksNodeCount,
				},
			},
			Identity: &containerservice.ManagedClusterIdentityArgs{
				Type: containerservice.ResourceIdentityTypeSystemAssigned,
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
			NetworkProfile: &containerservice.ContainerServiceNetworkProfileArgs{
				NetworkPlugin: aksNetworkPlugin,
			},
			DnsPrefix:    pulumi.Sprintf("aks-%v", randomPet),
			ResourceName: pulumi.Sprintf("aks-%v", randomPet),
		})
		if err != nil {
			return err
		}

		// Create Azure role assignments
		if err = assignRoles(ctx, deploymentTypes{
			resourceGroup:         resourceGroup,
			containerRegistry:     containerRegistry,
			azureMonitorWorkspace: azureMonitorWorkspace,
			grafanaDashboard:      grafanaDashboard,
			managedCluster:        managedCluster,
		}); err != nil {
			return err
		}

		// Onboard container insights to AKS cluster
		if err = onboardInsights(ctx, deploymentTypes{
			resourceGroup:         resourceGroup,
			logAnalyticsWorkspace: logAnalyticsWorkspace,
			azureMonitorWorkspace: azureMonitorWorkspace,
			managedCluster:        managedCluster,
		}); err != nil {
			return nil
		}

		return nil
	})
}
