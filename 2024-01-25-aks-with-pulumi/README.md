# Pulumi up to AKS

This sample will deploy an Azure Kubernetes Service (AKS) cluster using [Pulumi's azure-native Go SDK](https://www.pulumi.com/registry/packages/azure-native/) and onboard the following features for cluster monitoring:

- Managed Prometheus for metric collection
- Container insights for log collection
- Managed Grafana for visualization

To get started with this sample, you will need to have the following installed:

- [Azure Subscription](https://azure.microsoft.com/get-started/)
- [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli)
- [Pulumi](https://www.pulumi.com/docs/get-started/install/)
- [Go](https://golang.org/doc/install)

## Getting Started

To get started, clone this repository and navigate to the `2024-01-25-aks-with-pulumi` directory. 

Next, make sure you are logged into the Azure CLI and have the following extensions installed:

```bash
az login
```

You have an option when running the `pulumi up` command. You can use Pulumi's managed service to store your state or you can use a local state file. If you want to use Pulumi's managed service, you can run the following command:

```bash
pulumi login
```

If you want to use a local state file, you can run the following command:

```bash
pulumi login file://~/.pulumi
```

> You will be asked to create a `PULUMI_CONFIG_PASSPHRASE` when using a local state file. This is used to encrypt the state file and can be any string you choose.

Pulumi stores deployment state within stacks. This helps you manage different deployments of your infrastructure. You can create a new stack using the following command:

```bash
pulumi stack init dev
```

Before running the `pulumi up` command, be sure to configure the location for the resources using the following command:

```bash
pulumi config set azure-native:location <YOUR_PREFERRED_AZURE_REGION>
```

> Just make sure the region you choose supports AKS, Azure Monitor, and Azure Grafana.

The following command will install the `azure-native` plugin:

```bash
pulumi up -s dev
```

After running the `pulumi up` command, you will be prompted to confirm the changes. If everything looks good, you can type `yes` and hit enter. Within a few minutes, you will have an AKS cluster deployed in your Azure subscription.

From here, feel free to explore the cluster and the resources that were created and deploy your favorite application to the cluster.

## Clean up

To clean up the resources, you can run the following commands:

```bash
pulumi destroy -s dev
pulumi stack rm dev
```

## Resources

- [Pulumi's `azure-native` Go SDK](https://www.pulumi.com/registry/packages/azure-native/)
- [Azure Kubernetes Service (AKS)](https://learn.microsoft.com/azure/aks/)
- [Azure Monitor managed service for Prometheus](https://learn.microsoft.com/azure/azure-monitor/essentials/prometheus-metrics-overview)
- [Azure Managed Grafana](https://learn.microsoft.com/azure/managed-grafana/overview)
- [Azure Monitor for containers](https://learn.microsoft.com/azure/azure-monitor/containers/container-insights-overview)
- [Enable monitoring for Kubernetes clusters](https://learn.microsoft.com/azure/azure-monitor/containers/kubernetes-monitoring-enable?tabs=arm)
