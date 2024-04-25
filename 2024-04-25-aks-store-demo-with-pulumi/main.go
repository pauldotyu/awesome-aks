package main

import (
	"encoding/base64"

	"github.com/pulumi/pulumi-azure-native-sdk/appconfiguration/v2"
	"github.com/pulumi/pulumi-azure-native-sdk/cognitiveservices/v2"
	"github.com/pulumi/pulumi-azure-native-sdk/containerregistry/v2"
	"github.com/pulumi/pulumi-azure-native-sdk/containerservice/v2"
	"github.com/pulumi/pulumi-azure-native-sdk/dashboard/v2"
	"github.com/pulumi/pulumi-azure-native-sdk/documentdb/v2"
	"github.com/pulumi/pulumi-azure-native-sdk/insights/v2"
	"github.com/pulumi/pulumi-azure-native-sdk/managedidentity/v2"
	"github.com/pulumi/pulumi-azure-native-sdk/monitor"
	"github.com/pulumi/pulumi-azure-native-sdk/operationalinsights/v2"
	"github.com/pulumi/pulumi-azure-native-sdk/resources/v2"
	"github.com/pulumi/pulumi-azure-native-sdk/servicebus/v2"
	"github.com/pulumi/pulumi-kubernetes/sdk/v4/go/kubernetes"
	corev1 "github.com/pulumi/pulumi-kubernetes/sdk/v4/go/kubernetes/core/v1"
	"github.com/pulumi/pulumi-kubernetes/sdk/v4/go/kubernetes/helm/v3"
	v1 "github.com/pulumi/pulumi-kubernetes/sdk/v4/go/kubernetes/meta/v1"
	"github.com/pulumi/pulumi/sdk/v3/go/pulumi"
)

const (
	aksNodeCount            = pulumi.Int(3)
	aksNodeVMSize           = pulumi.String("Standard_DS4_v2")
	aksNodeName             = pulumi.String("nodepool1")
	aksNodeMode             = pulumi.String("System")
	aksNetworkPlugin        = pulumi.String("azure")
	aksNetworkPluginMode    = pulumi.String("overlay")
	aksNetworkPolicy        = pulumi.String("cilium")
	aksNetworkDataPlane     = pulumi.String("cilium")
	acrSku                  = pulumi.String("Premium")
	acrPullRoleId           = pulumi.String("/providers/Microsoft.Authorization/roleDefinitions/7f951dda-4ed3-4680-a7ca-43fe172d538d")
	monitorReaderRoleID     = pulumi.String("/providers/Microsoft.Authorization/roleDefinitions/43d0d8ad-25c7-4714-9337-8ba259a9fe05")
	grafanaAdminRoleID      = pulumi.String("/providers/Microsoft.Authorization/roleDefinitions/22926164-76b3-42b3-bc55-97df8dab3e41")
	openAiContributorRoleID = pulumi.String("/providers/Microsoft.Authorization/roleDefinitions/a001fd3d-188f-4b5d-821b-7da978bf7442")
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
			ResourceName:      pulumi.Sprintf("aks-%v", randomPet),
			DnsPrefix:         pulumi.Sprintf("aks-%v", randomPet),
			AddonProfiles: containerservice.ManagedClusterAddonProfileMap{
				"omsagent": &containerservice.ManagedClusterAddonProfileArgs{
					Enabled: pulumi.Bool(true),
					Config: pulumi.StringMap{
						"logAnalyticsWorkspaceResourceID": logAnalyticsWorkspace.ID(),
						"useAADAuth":                      pulumi.String("true"),
					},
				},
				"azureKeyvaultSecretsProvider": &containerservice.ManagedClusterAddonProfileArgs{
					Config: pulumi.StringMap{
						"enableSecretRotation": pulumi.String("true"),
					},
					Enabled: pulumi.Bool(true),
				},
				"azurepolicy": &containerservice.ManagedClusterAddonProfileArgs{
					Enabled: pulumi.Bool(true),
				},
			},
			AgentPoolProfiles: containerservice.ManagedClusterAgentPoolProfileArray{
				&containerservice.ManagedClusterAgentPoolProfileArgs{
					Mode:    aksNodeMode,
					Name:    aksNodeName,
					VmSize:  aksNodeVMSize,
					Count:   aksNodeCount,
					OsSKU:   pulumi.String("Ubuntu"),
					MaxPods: pulumi.Int(250),
				},
			},
			AutoUpgradeProfile: &containerservice.ManagedClusterAutoUpgradeProfileArgs{
				UpgradeChannel: pulumi.String("NodeImage"),
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
			NetworkProfile: &containerservice.ContainerServiceNetworkProfileArgs{
				NetworkPlugin: aksNetworkPlugin,
			},
			OidcIssuerProfile: &containerservice.ManagedClusterOIDCIssuerProfileArgs{
				Enabled: pulumi.Bool(true),
			},
			SecurityProfile: &containerservice.ManagedClusterSecurityProfileArgs{
				WorkloadIdentity: &containerservice.ManagedClusterSecurityProfileWorkloadIdentityArgs{
					Enabled: pulumi.Bool(true),
				},
				ImageCleaner: &containerservice.ManagedClusterSecurityProfileImageCleanerArgs{
					Enabled:       pulumi.Bool(true),
					IntervalHours: pulumi.Int(168),
				},
			},
			WorkloadAutoScalerProfile: &containerservice.ManagedClusterWorkloadAutoScalerProfileArgs{
				Keda: &containerservice.ManagedClusterWorkloadAutoScalerProfileKedaArgs{
					Enabled: pulumi.Bool(true),
				},
			},
		})
		if err != nil {
			return err
		}

		// Create Azure Application Configuration
		appConfigurationStore, err := appconfiguration.NewConfigurationStore(ctx, "appConfigurationStore", &appconfiguration.ConfigurationStoreArgs{
			ConfigStoreName:   pulumi.Sprintf("ac-%v", randomPet),
			Location:          resourceGroup.Location,
			ResourceGroupName: resourceGroup.Name,
			Sku: &appconfiguration.SkuArgs{
				Name: pulumi.String("Standard"),
			},
		})
		if err != nil {
			return err
		}

		// Create identity for Azure Application Configuration
		appConfigurationStoreIdentity, err := managedidentity.NewUserAssignedIdentity(ctx, "appConfigurationStoreIdentity", &managedidentity.UserAssignedIdentityArgs{
			Location:          resourceGroup.Location,
			ResourceGroupName: resourceGroup.Name,
			ResourceName:      pulumi.Sprintf("ac-%v", randomPet),
		})
		if err != nil {
			return err
		}

		// Create federated credential for Azure Application Configuration identity
		_, err = managedidentity.NewFederatedIdentityCredential(ctx, "appConfigurationStoreCredential", &managedidentity.FederatedIdentityCredentialArgs{
			FederatedIdentityCredentialResourceName: appConfigurationStoreIdentity.Name,
			ResourceName:                            appConfigurationStoreIdentity.Name,
			ResourceGroupName:                       resourceGroup.Name,
			Issuer:                                  managedCluster.OidcIssuerProfile.Elem().IssuerURL().ToStringOutput(),
			Subject:                                 pulumi.String("system:serviceaccount:azappconfig-system:az-appconfig-k8s-provider"),
			Audiences: pulumi.StringArray{
				pulumi.String("api://AzureADTokenExchange"),
			},
		})
		if err != nil {
			return err
		}

		// Get cluster credentials
		managedClusterCredentials := containerservice.ListManagedClusterUserCredentialsOutput(ctx, containerservice.ListManagedClusterUserCredentialsOutputArgs{
			ResourceGroupName: resourceGroup.Name,
			ResourceName:      managedCluster.Name,
		})

		// Get kubeconfig
		kubeConfig := managedClusterCredentials.Kubeconfigs().Index(pulumi.Int(0)).Value().
			ApplyT(func(arg string) string {
				kubeconfig, err := base64.StdEncoding.DecodeString(arg)
				if err != nil {
					return ""
				}
				return string(kubeconfig)
			}).(pulumi.StringOutput)

		// Build Kubernetes provider
		k8sProvider, err := kubernetes.NewProvider(ctx, "k8sProvider", &kubernetes.ProviderArgs{
			Kubeconfig: kubeConfig,
		})
		if err != nil {
			return err
		}

		// Create the azappconfig-system namespace
		_, err = corev1.NewNamespace(ctx, "azappconfig-system", &corev1.NamespaceArgs{
			Metadata: v1.ObjectMetaArgs{
				Name: pulumi.String("azappconfig-system"),
			},
		}, pulumi.Provider(k8sProvider))
		if err != nil {
			return err
		}

		// Install the Azure Application Configuration Kubernetes provider
		_, err = helm.NewChart(ctx, "azappconfig-provider", helm.ChartArgs{
			Chart:     pulumi.String("oci://mcr.microsoft.com/azure-app-configuration/helmchart/kubernetes-provider"),
			Namespace: pulumi.String("azappconfig-system"),
		}, pulumi.Provider(k8sProvider))
		if err != nil {
			return err
		}

		// Create Azure OpenAI
		cognitiveServicesAccount, err := cognitiveservices.NewAccount(ctx, "cognitiveServicesAccount", &cognitiveservices.AccountArgs{
			Location:          resourceGroup.Location,
			ResourceGroupName: resourceGroup.Name,
			AccountName:       pulumi.Sprintf("ai-%v", randomPet),
			Identity: &cognitiveservices.IdentityArgs{
				Type: cognitiveservices.ResourceIdentityTypeSystemAssigned,
			},
			Kind: pulumi.String("OpenAI"),
			Properties: &cognitiveservices.AccountPropertiesArgs{
				CustomSubDomainName: pulumi.Sprintf("ai-%v", randomPet),
				DisableLocalAuth:    pulumi.Bool(true),
			},
			Sku: &cognitiveservices.SkuArgs{
				Name: pulumi.String("S0"),
			},
		})
		if err != nil {
			return err
		}

		// Create identity for Azure OpenAI
		_, err = managedidentity.NewUserAssignedIdentity(ctx, "cognitiveServicesAccountIdentity", &managedidentity.UserAssignedIdentityArgs{
			Location:          resourceGroup.Location,
			ResourceGroupName: resourceGroup.Name,
			ResourceName:      pulumi.Sprintf("ai-%v", randomPet),
		})
		if err != nil {
			return err
		}

		// Create gpt-35-turbo model for Azure OpenAI
		_, err = cognitiveservices.NewDeployment(ctx, "gpt35turboModel", &cognitiveservices.DeploymentArgs{
			AccountName:       cognitiveServicesAccount.Name,
			DeploymentName:    pulumi.String("gpt-35-turbo"),
			ResourceGroupName: resourceGroup.Name,
			Sku: &cognitiveservices.SkuArgs{
				Capacity: pulumi.Int(1),
				Name:     pulumi.String("Standard"),
			},
			Properties: &cognitiveservices.DeploymentPropertiesArgs{
				Model: &cognitiveservices.DeploymentModelArgs{
					Format:  pulumi.String("OpenAI"),
					Version: pulumi.String("0301"),
					Name:    pulumi.String("gpt-35-turbo"),
				},
			},
		})
		if err != nil {
			return err
		}

		// Create dall-e-3 model for Azure OpenAI
		_, err = cognitiveservices.NewDeployment(ctx, "dalle3Model", &cognitiveservices.DeploymentArgs{
			AccountName:       cognitiveServicesAccount.Name,
			ResourceGroupName: resourceGroup.Name,
			DeploymentName:    pulumi.String("dall-e-3"),
			Sku: &cognitiveservices.SkuArgs{
				Name:     pulumi.String("Standard"),
				Capacity: pulumi.Int(1),
			},
			Properties: &cognitiveservices.DeploymentPropertiesArgs{
				Model: &cognitiveservices.DeploymentModelArgs{
					Format:  pulumi.String("OpenAI"),
					Version: pulumi.String("3.0"),
					Name:    pulumi.String("dall-e-3"),
				},
			},
		})
		if err != nil {
			return err
		}

		// Create Azure Service Bus
		serviceBusNamespace, err := servicebus.NewNamespace(ctx, "serviceBusNamespace", &servicebus.NamespaceArgs{
			Location:          resourceGroup.Location,
			ResourceGroupName: resourceGroup.Name,
			NamespaceName:     pulumi.Sprintf("sb-%v", randomPet),
			DisableLocalAuth:  pulumi.Bool(true),
			Sku: &servicebus.SBSkuArgs{
				Name: pulumi.String(servicebus.SkuNameStandard),
				Tier: pulumi.String(servicebus.SkuTierStandard),
			},
		})
		if err != nil {
			return err
		}

		// Create identity for Azure Service Bus
		_, err = managedidentity.NewUserAssignedIdentity(ctx, "serviceBusNamespaceIdentity", &managedidentity.UserAssignedIdentityArgs{
			Location:          resourceGroup.Location,
			ResourceGroupName: resourceGroup.Name,
			ResourceName:      pulumi.Sprintf("sb-%v", randomPet),
		})
		if err != nil {
			return err
		}

		// Create Azure Service Bus Queue
		_, err = servicebus.NewQueue(ctx, "queue", &servicebus.QueueArgs{
			EnablePartitioning: pulumi.Bool(true),
			NamespaceName:      serviceBusNamespace.Name,
			ResourceGroupName:  resourceGroup.Name,
			QueueName:          pulumi.String("orders"),
		})
		if err != nil {
			return err
		}

		// Create diagnostic setting for Azure Service Bus
		_, err = insights.NewDiagnosticSetting(ctx, "serviceBusNamespaceDiagnosticSetting", &insights.DiagnosticSettingArgs{
			LogAnalyticsDestinationType: pulumi.String("Dedicated"),
			Logs: insights.LogSettingsArray{
				&insights.LogSettingsArgs{
					CategoryGroup: pulumi.String("allLogs"),
					Enabled:       pulumi.Bool(true),
					RetentionPolicy: &insights.RetentionPolicyArgs{
						Days:    pulumi.Int(0),
						Enabled: pulumi.Bool(false),
					},
				},
			},
			Metrics: insights.MetricSettingsArray{
				&insights.MetricSettingsArgs{
					Category: pulumi.String("AllMetrics"),
					Enabled:  pulumi.Bool(true),
					RetentionPolicy: &insights.RetentionPolicyArgs{
						Days:    pulumi.Int(0),
						Enabled: pulumi.Bool(false),
					},
				},
			},
			Name:        pulumi.String("serviceBusNamespaceDiagnosticSetting"),
			ResourceUri: serviceBusNamespace.ID(),
			WorkspaceId: logAnalyticsWorkspace.ID(),
		})
		if err != nil {
			return err
		}

		// Create Azure CosmosDB
		databaseAccount, err := documentdb.NewDatabaseAccount(ctx, "databaseAccount", &documentdb.DatabaseAccountArgs{
			Location:                 resourceGroup.Location,
			ResourceGroupName:        resourceGroup.Name,
			AccountName:              pulumi.Sprintf("db-%v", randomPet),
			DisableLocalAuth:         pulumi.Bool(true),
			DatabaseAccountOfferType: documentdb.DatabaseAccountOfferTypeStandard,
			Kind:                     pulumi.String("GlobalDocumentDB"),
			Locations: documentdb.LocationArray{
				&documentdb.LocationArgs{
					FailoverPriority: pulumi.Int(0),
					IsZoneRedundant:  pulumi.Bool(false),
					LocationName:     resourceGroup.Location,
				},
			},
		})
		if err != nil {
			return err
		}

		// Create identity for Azure CosmosDB
		_, err = managedidentity.NewUserAssignedIdentity(ctx, "databaseAccountIdentity", &managedidentity.UserAssignedIdentityArgs{
			Location:          resourceGroup.Location,
			ResourceGroupName: resourceGroup.Name,
			ResourceName:      pulumi.Sprintf("db-%v", randomPet),
		})
		if err != nil {
			return err
		}

		// Create Azure CosmosDB database
		sqlResourceSqlDatabase, err := documentdb.NewSqlResourceSqlDatabase(ctx, "sqlResourceSqlDatabase", &documentdb.SqlResourceSqlDatabaseArgs{
			AccountName:       databaseAccount.Name,
			DatabaseName:      pulumi.String("orderdb"),
			ResourceGroupName: resourceGroup.Name,
			Location:          resourceGroup.Location,
			Options:           nil,
			Resource: &documentdb.SqlDatabaseResourceArgs{
				Id: pulumi.String("orderdb"),
			},
		})
		if err != nil {
			return err
		}

		// Create Azure CosmosDB container
		_, err = documentdb.NewSqlResourceSqlContainer(ctx, "sqlResourceSqlContainer", &documentdb.SqlResourceSqlContainerArgs{
			AccountName:       databaseAccount.Name,
			DatabaseName:      sqlResourceSqlDatabase.Name,
			ContainerName:     pulumi.String("orders"),
			ResourceGroupName: resourceGroup.Name,
			Location:          resourceGroup.Location,
			Resource: &documentdb.SqlContainerResourceArgs{
				Id: pulumi.String("orders"),
				PartitionKey: &documentdb.ContainerPartitionKeyArgs{
					Kind: pulumi.String(documentdb.PartitionKindHash),
					Paths: pulumi.StringArray{
						pulumi.String("/storeId"),
					},
				},
			},
		})
		if err != nil {
			return err
		}

		// Create Azure role assignments
		if err = assignRoles(ctx, deploymentTypes{
			resourceGroup:            resourceGroup,
			containerRegistry:        containerRegistry,
			azureMonitorWorkspace:    azureMonitorWorkspace,
			grafanaDashboard:         grafanaDashboard,
			managedCluster:           managedCluster,
			cognitiveServicesAccount: cognitiveServicesAccount,
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

		// Add appconfigs
		if err = addAppConfigs(ctx, deploymentTypes{
			resourceGroup:         resourceGroup,
			appConfigurationStore: appConfigurationStore,
		}); err != nil {
			return nil
		}

		// stack outputs
		ctx.Export("resourceGroupName", pulumi.All(resourceGroup.Name).ApplyT(
			func(args []interface{}) string {
				return args[0].(string)
			},
		))

		ctx.Export("aksName", pulumi.All(managedCluster.Name).ApplyT(
			func(args []interface{}) string {
				return args[0].(string)
			},
		))
		ctx.Export("openAiEndpoint", pulumi.All(cognitiveServicesAccount.Properties).ApplyT(
			func(args []interface{}) string {
				return args[0].(cognitiveservices.AccountPropertiesResponse).Endpoint
			},
		))

		apiKeys := cognitiveservices.ListAccountKeysOutput(ctx, cognitiveservices.ListAccountKeysOutputArgs{
			AccountName:       cognitiveServicesAccount.Name,
			ResourceGroupName: resourceGroup.Name,
		})
		ctx.Export("openAiKey", apiKeys.Key1().ToStringPtrOutput())

		return nil
	})
}
